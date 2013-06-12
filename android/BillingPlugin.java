package com.tealeaf.plugin.plugins;
import java.util.Map;
import org.json.JSONObject;
import org.json.JSONArray;
import org.json.JSONException;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentActivity;
import com.tealeaf.EventQueue;
import com.tealeaf.TeaLeaf;
import com.tealeaf.logger;
import com.tealeaf.event.PluginEvent;
import android.content.pm.PackageManager;
import android.content.pm.ApplicationInfo;
import android.os.Bundle;
import java.util.HashMap;
import java.util.ArrayList;

import com.tealeaf.plugin.IPlugin;
import android.app.Activity;
import android.app.AlertDialog;
import android.app.AlertDialog.Builder;
import android.content.Intent;
import android.content.Context;
import android.content.DialogInterface;
import android.content.ServiceConnection;
import android.util.Log;

import android.content.ComponentName;
import android.os.IBinder;
import android.app.PendingIntent;

import com.tealeaf.EventQueue;
import com.tealeaf.event.*;

import com.android.vending.billing.IInAppBillingService;

public class BillingPlugin implements IPlugin {
	Context _ctx;
	Activity _activity;
	IInAppBillingService mService;
	ServiceConnection mServiceConn;
	static private final int BUY_REQUEST_CODE = 123450;

	public class PurchaseEvent extends com.tealeaf.event.Event {
		String sku;
		String reason;

		public PurchaseEvent(String sku, String reason) {
			super("billingPurchase");
			this.sku = sku;
			this.reason = reason;
		}
	}

	public class OwnedEvent extends com.tealeaf.event.Event {
		ArrayList<String> skus;

		public OwnedEvent(ArrayList<String> skus) {
			super("billingOwned");
			this.skus = skus;
		}
	}

	public BillingPlugin() {
	}

	public void onCreateApplication(Context applicationContext) {
		_ctx = applicationContext;

		mServiceConn = new ServiceConnection() {
			@Override
				public void onServiceDisconnected(ComponentName name) {
					mService = null;
				}

			@Override
				public void onServiceConnected(ComponentName name, 
						IBinder service) {
					mService = IInAppBillingService.Stub.asInterface(service);
				}
		};
	}

	public void onCreate(Activity activity, Bundle savedInstanceState) {
		logger.log("{billing} Installing listener");

		_activity = activity;

		_ctx.bindService(new 
				Intent("com.android.vending.billing.InAppBillingService.BIND"),
				mServiceConn, Context.BIND_AUTO_CREATE);
	}

	public void onResume() {
	}

	public void onStart() {
	}

	public void onPause() {
	}

	public void onStop() {
	}

	public void onDestroy() {
		if (mServiceConn != null) {
			_ctx.unbindService(mServiceConn);
		}
	}

	public void purchase(String jsonData) {
		boolean success = false;
		String sku = null;

		try {
			logger.log("{billing} Purchase");

			JSONObject jsonObject = new JSONObject(jsonData);
			sku = jsonObject.getString("sku");

			// TODO: Add additional security with extra field ("1")

			Bundle buyIntentBundle = mService.getBuyIntent(3, _ctx.getPackageName(),
					sku, "inapp", "1");

			// If unable to create bundle,
			if (buyIntentBundle == null || buyIntentBundle.getInt("RESPONSE_CODE", 1) != 0) {
				logger.log("{billing} WARNING: Unable to create intent bundle for sku", sku);
			} else {
				PendingIntent pendingIntent = buyIntentBundle.getParcelable("BUY_INTENT");

				if (pendingIntent == null) {
					logger.log("{billing} WARNING: Unable to create pending intent for sku", sku);
				} else {
					_activity.startIntentSenderForResult(pendingIntent.getIntentSender(),
							BUY_REQUEST_CODE, new Intent(), Integer.valueOf(0),
							Integer.valueOf(0), Integer.valueOf(0));
					success = true;
				}
			}
		} catch (Exception e) {
			logger.log("{billing} WARNING: Failure in purchase:", e);
		}

		if (!success && sku != null) {
			EventQueue.pushEvent(new PurchaseEvent(sku, "failed"));
		}
	}

	public void getPurchases(String jsonData) {
		ArrayList<String> skus = new ArrayList<String>();

		try {
			logger.log("{billing} Getting prior purchases");

			Bundle ownedItems = mService.getPurchases(3, _ctx.getPackageName(), "inapp", null);

			// If unable to create bundle,
			int responseCode = ownedItems.getInt("RESPONSE_CODE", 1);
			if (responseCode != 0) {
				logger.log("{billing} WARNING: Failure to create owned items bundle:", responseCode);
			} else {
				ArrayList ownedSkus = 
					ownedItems.getStringArrayList("INAPP_PURCHASE_ITEM_LIST");
				//ArrayList purchaseDataList = 
				//	ownedItems.getStringArrayList("INAPP_PURCHASE_DATA_LIST");
				//ArrayList signatureList = 
				//	ownedItems.getStringArrayList("INAPP_DATA_SIGNATURE");
				//String continuationToken = 
				//	ownedItems.getString("INAPP_CONTINUATION_TOKEN");

				for (int i = 0; i < ownedSkus.size(); ++i) {
					//String purchaseData = purchaseDataList.get(i);
					//String signature = signatureList.get(i);
					String sku = (String)ownedSkus.get(i);

					// TODO: Provide purchase data
					// TODO: Verify signatures

					skus.add(sku);
				} 

				// TODO: Use continuationToken to retrieve > 700 items
			}
		} catch (Exception e) {
			logger.log("{billing} WARNING: Failure in getPurchases:", e);
		}

		EventQueue.pushEvent(new OwnedEvent(skus));
	}

	public void onActivityResult(Integer request, Integer resultCode, Intent data) {
		if (request == BUY_REQUEST_CODE) {
			String purchaseData = data.getStringExtra("INAPP_PURCHASE_DATA");
			String sku = null;

			if (purchaseData == null) {
				logger.log("{billing} WARNING: Ignored null purchase data");
			} else {
				try {
					JSONObject jo = new JSONObject(purchaseData);
					sku = jo.getString("productId");

					if (sku == null) {
						logger.log("{billing} WARNING: Malformed purchase json");
					} else {
						switch (resultCode) {
							case Activity.RESULT_OK:
								logger.log("{billing} Successfully purchased SKU:", sku);
								EventQueue.pushEvent(new PurchaseEvent(sku, null));
								break;
							case Activity.RESULT_CANCELED:
								logger.log("{billing} Purchase canceled for SKU:", sku);
								EventQueue.pushEvent(new PurchaseEvent(sku, "cancel"));
								break;
							default:
								logger.log("{billing} WARNING: Unexpected response code", resultCode);
						}
					}
				}
				catch (JSONException e) {
					logger.log("{billing} WARNING: Failed to parse purchase data:", e);
				}
			}
		}
	}

	public void onNewIntent(Intent intent) {
	}

	public void setInstallReferrer(String referrer) {
	}

	public void logError(String error) {
	}

	public boolean consumeOnBackPressed() {
		return false;
	}

	public void onBackPressed() {
	}
}

