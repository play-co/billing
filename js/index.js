import device;
import event.Emitter as Emitter;
import util.setProperty as setProperty;

/*
 * Items are first purchased, and then consumed.
 *
 * When they are consumed they must not be lost, so they are either
 * delivered to the billing.onPurchase callback or must be stored in
 * localStorage for delivery on the next run.
 */

var purchasedItems = {};
var consumedItems = {};
var onPurchase; // callback after consumption
var onFailure; // callback on purchase failure (not consume fail)

/*
 * Read the list of consumed items during startup.
 */
function initializeFromLocalStorage() {
	try {
		var saved = localStorage.getItem("billingConsumed");

		if (saved) {
			var consumed = JSON.parse(saved);

			if (typeof consumed === "object") {
				// Merge with consumed items
				var count = 0;
				for (var item in consumed) {
					consumedItems[item] = 1;
					++count;
				}
				logger.log("Read", count, "consumed purchased items");
			}
		}
	} catch (e) {
		logger.log("Failed to read consumed items from local storage:", e);
	}
}

/*
 * Mark an item as purchased but not consumed yet.
 *
 * This list is grabbed from the market so we do not need to store this
 * information locally, yet.
 */
function purchasedItem(item) {
	try {
		purchasedItems[item] = 1;
	} catch (e) {
		logger.log("Purchase update failed with error:", e);
	}
}

/*
 * Attempt to credit a player for their consumed item, and remove it from the
 * consumed items list in local storage on success.
 */
function creditConsumedItem(item) {
	try {
		if (typeof onPurchase === "function" && consumedItems[item]) {
			try {
				onPurchase(item);
			} catch(e) {
				logger.log("onPurchase CALLBACK FAILURE!")
			}

			// emit purchaseWithReceipt event
			if (itemSignature[item]) {
				billing.emit('purchaseWithReceipt', {
					sku: item,
					signature: itemSignature[item]
				});
			}
			delete consumedItems[item];
			localStorage.setItem("billingConsumed", JSON.stringify(consumedItems));

			logger.log("Successfully credited consumed item:", item);
		}
	} catch (e) {
		logger.log("Crediting purchase failed with error:", e);
	}
}

/*
 * Move an item from the purchased list to the consumed list and update
 * local storage so that it does not get lost.
 */
function consumePurchasedItem(item) {
	try {
		if (purchasedItems[item]) {
			delete purchasedItems[item];
			consumedItems[item] = 1;

			localStorage.setItem("billingConsumed", JSON.stringify(consumedItems));

			logger.log("Successfully consumed purchased item:", item);

			creditConsumedItem(item);
		}
	} catch (e) {
		logger.log("Crediting purchase failed with error:", e);
	}
}

/*
 * Credit all outstanding consumed items.
 */
function creditAllConsumedItems() {
	var consumed = [];

	for (var item in consumedItems) {
		if (consumedItems[item]) {
			consumed.push(item);
		}
	}

	for (var ii = 0; ii < consumed.length; ++ii) {
		var item = consumed[ii];

		creditConsumedItem(item);
	}
}

/*
 * Run purchase simulation.
 */
function simulatePurchase(item, simulate) {
	if (!simulate || simulate === "simulate") {
		setTimeout(function() {
			logger.log("Simulating item purchase:", item);
			if (!purchasedItems[item]) {
				purchasedItem(item);
				setTimeout(function() {
					logger.log("Simulating item consume:", item);
					consumePurchasedItem(item);
				}, 2000);
			} else {
				logger.log("Item is already purchased.");
				if (typeof onFailure === "function") {
					onFailure("already owned", item);
				}
			}
		}, 2000);
	} else {
		setTimeout(function() {
			logger.log("Simulating item failure:", item);
			if (typeof onFailure === "function") {
				onFailure(simulate, item);
			}
		}, 1000);
	}
}

// Run initialization tasks
initializeFromLocalStorage();

// Maps of tokens <-> items from market
var tokenItem = {};
var itemToken = {};
var itemSignature = {};

// Flag: Has read purchases from the market?
var readPurchases = false;

// Flag: Is market service connected?
var isConnected = true;

// Flag: Is connected to the Internet?
var isOnline = navigator.onLine;

// Flag: Is market available?
var isMarketAvailable = false;

var Billing = Class(Emitter, function (supr) {
	this.init = function() {
		supr(this, 'init', arguments);

		setProperty(this, "onPurchase", {
			set: function(f) {
				// If a callback is being set,
				if (typeof f === "function") {
					onPurchase = f;

					creditAllConsumedItems();
				} else {
					onPurchase = null;
				}
			},
			get: function() {
				return onPurchase;
			}
		});

		setProperty(this, "onFailure", {
			set: function(f) {
				// If a callback is being set,
				if (typeof f === "function") {
					onFailure = f;
				} else {
					onFailure = null;
				}
			},
			get: function() {
				return onFailure;
			}
		});

		setProperty(this, "isMarketAvailable", {
			set: function(f) {
			},
			get: function() {
				return isMarketAvailable == true;
			}
		});
	};

	this.purchase = simulatePurchase;
});

var billing = new Billing;

function onMarketStateChange() {
	var available = isConnected && isOnline;

	if (available != isMarketAvailable) {
		isMarketAvailable = available;

		if (available) {
			logger.log("Market is now available");
		} else {
			logger.log("Market is now unavailable");
		}

		billing.emit("MarketAvailable", available);
	}
}

// If just simulating native device,
if (!GLOBAL.NATIVE || device.isSimulator || DEBUG) {
	logger.log("Installing fake billing API");
} else {
	logger.log("Installing JS billing component for native");

	// Override purchase function to hook into native
	Billing.prototype.purchase = function(item, simulate) {
		if (simulate) {
			if (simulate == "simulate") {
				NATIVE.plugins.sendEvent("BillingPlugin", "purchase", JSON.stringify({
					"sku": "android.test.purchased"
				}));
			} else if (simulate == "cancel") {
				NATIVE.plugins.sendEvent("BillingPlugin", "purchase", JSON.stringify({
					"sku": "android.test.canceled"
				}));
			} else if (simulate == "refund") {
				NATIVE.plugins.sendEvent("BillingPlugin", "purchase", JSON.stringify({
					"sku": "android.test.refunded"
				}));
			} else if (simulate == "unavailable") {
				NATIVE.plugins.sendEvent("BillingPlugin", "purchase", JSON.stringify({
					"sku": "android.test.unavailable"
				}));
			} else {
				NATIVE.plugins.sendEvent("BillingPlugin", "purchase", JSON.stringify({
					"sku": "android.test.canceled"
				}));
			}
		} else {
			NATIVE.plugins.sendEvent("BillingPlugin", "purchase", JSON.stringify({
				"sku": item
			}));
		}
	};

	var onRestore;

	Billing.prototype.restore = function(cb) {
		NATIVE.plugins.sendEvent("BillingPlugin", "restoreCompleted", "{}");

		onRestore = cb;
	}

	NATIVE.events.registerHandler('billingRestore', function(evt) {
		logger.log("Got billingRestore event:", JSON.stringify(evt));

		if (typeof onRestore == "function") {
			onRestore(evt.failure);
		}
	});

	// Request initial market state
	NATIVE.plugins.sendEvent("BillingPlugin", "isConnected", "{}");

	function nativePurchasedItem(sku, token, signature) {
		// Set up map
		tokenItem[token] = sku;
		itemToken[sku] = token;
		itemSignature[sku] = signature;

		// Record purchases
		purchasedItem(sku);

		// Attempt to consume it immediately
		NATIVE.plugins.sendEvent("BillingPlugin", "consume", JSON.stringify({
			token: token
		}));
	}

	NATIVE.events.registerHandler('billingPurchase', function(evt) {
		logger.log("Got billingPurchase event:", JSON.stringify(evt));

		// If SKU event,
		var sku = evt.sku;
		if (!sku || evt.failure) {
			var failure = evt.failure || "cancel";

			logger.log("Unable to purchase item", sku, ":", failure);

			if (typeof onFailure === "function") {
				onFailure(failure, sku);
			}
		} else {
			nativePurchasedItem(sku, evt.token, evt.signature);
		}
	});

	NATIVE.events.registerHandler('billingConsume', function(evt) {
		logger.log("Got billingConsume event:", JSON.stringify(evt));

		// NOTE: Function is organized carefully for callback reentrancy

		var token = evt.token;
		var item = tokenItem[token];

		// If not failed,
		if (!evt.failure) {
			consumePurchasedItem(item);
		} else {
			logger.log("Failed to consume token", token, "for item", item, "and will retry in 3 seconds...");

			setTimeout(function() {
				NATIVE.plugins.sendEvent("BillingPlugin", "consume", JSON.stringify({
					token: token
				}));
			}, 3000);
		}
	});

	// Wait a couple of seconds to avoid slowing down the startup process
	var ownedRetryID = setTimeout(function() {
		ownedRetryID = null;
		if (!readPurchases) {
			NATIVE.plugins.sendEvent("BillingPlugin", "getPurchases", "{}");
		}
	}, 3000);

	NATIVE.events.registerHandler('billingOwned', function(evt) {
		logger.log("Got billingOwned event:", JSON.stringify(evt));

		if (ownedRetryID !== null) {
			clearTimeout(ownedRetryID);
			ownedRetryID = null;
		}

		// If attempt failed,
		if (evt.failure) {
			ownedRetryID = setTimeout(function() {
				ownedRetryID = null;
				if (!readPurchases) {
					NATIVE.plugins.sendEvent("BillingPlugin", "getPurchases", "{}");
				}
			}, 10000);
		} else {
			readPurchases = true;

			// Add owned items
			var skus = evt.skus;
			var tokens = evt.tokens;
			var signatures = evt.signatures || [];
			if (skus && skus.length > 0) {
				for (var ii = 0, len = skus.length; ii < len; ++ii) {
					nativePurchasedItem(skus[ii], tokens[ii], signatures[ii]);
				}
			}
		}
	});

	NATIVE.events.registerHandler('billingConnected', function(evt) {
		logger.log("Got billingConnected event:", JSON.stringify(evt));

		isConnected = evt.connected;

		onMarketStateChange();
	});

	window.addEventListener("online", function() {
		isOnline = true;

		onMarketStateChange();
	});

	window.addEventListener("offline", function() {
		isOnline = false;

		onMarketStateChange();
	});

	billing.on("MarketAvailable", function(available) {
		// If just connected,
		if (available) {
			if (ownedRetryID !== null) {
				clearTimeout(ownedRetryID);
				ownedRetryID = null;
			}

			// Try to get purchases immediately to react faster
			if (!readPurchases) {
				NATIVE.plugins.sendEvent("BillingPlugin", "getPurchases", "{}");
			}
		}
	});
}

// Run initial state check
onMarketStateChange();

exports = billing;
