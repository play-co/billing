import device;
import util.setProperty as setProperty;

// If on true native mobile platform,
if (!GLOBAL.NATIVE || device.simulatingMobileNative) {
	logger.log("Installing fake billing API");
} else {
	logger.log("Installing JS billing component for native");

	var purchasing = {};
	var onPurchase = {};

	var gotOwned = false;
	var onOwned = [];
	var ownedSet = {};
	var ownedArray = [];

	var onConsume = {};
	var tokenSet = {};

	NATIVE.events.registerHandler('billingPurchase', function(evt) {
		logger.log("Got billingPurchase event:", JSON.stringify(evt));

		// NOTE: Function is organized carefully for callback reentrancy

		// If SKU event,
		var sku = evt.sku;
		if (!sku) {
			logger.log("Clearing all pending purchases on null SKU");

			// Clear all pending purchases
			for (var sku in ownedSet) {
				// If purchase callbacks are installed,
				var calls = onPurchase[sku];
				if (calls && calls.length > 0) {
					// For each callback,
					for (var ii = 0; ii < calls.length; ++ii) {
						// Run it
						calls[ii]("cancel");
					}

					// Clear callbacks
					calls.length = 0;
				}

				purchasing = {};
			}
		} else {
			// If not failed,
			if (!evt.failure) {
				// Mark it owned
				ownedSet[sku] = evt.token;
				tokenSet[evt.token] = sku;
				ownedArray.push(sku);
			}

			// If purchase callbacks are installed,
			var calls = onPurchase[sku];
			if (calls && calls.length > 0) {
				// For each callback,
				for (var ii = 0; ii < calls.length; ++ii) {
					// Run it
					calls[ii](evt.failure);
				}

				// Clear callbacks
				calls.length = 0;
			}

			// Disable purchasing flag
			purchasing[sku] = undefined;
		}
	});

	NATIVE.events.registerHandler('billingConsume', function(evt) {
		logger.log("Got billingConsume event:", JSON.stringify(evt));

		// NOTE: Function is organized carefully for callback reentrancy

		var token = evt.token;
		var sku = tokenSet[token];

		// If not failed,
		if (!evt.failure) {
			// Remove from lists
			ownedSet[sku] = undefined;
			tokenSet[token] = undefined;

			// Remove from ownedArray
			var index = ownedArray.indexOf(sku);
			ownedArray.splice(index, 1);
		}

		// Clear consume callback
		var call = onConsume[sku];
		onConsume[sku] = undefined;

		// Run consume callback
		call(evt.failure);
	});

	function handleOldPurchases(next) {
		if (typeof next !== "function") {
			logger.debug("WARNING: billing.handleOldPurchases ignored without a callback");
			return;
		}

		for (var ii = 0; ii < ownedArray.length; ++ii) {
			next(ownedArray[ii]);
		}
	}

	var Billing = Class(Emitter, function (supr) {
		var onPurchase, onFailure;

		this.init = function() {
			supr(this, 'init', arguments);

			setProperty(this, "onPurchase", {
				set: function(f) {
					onPurchase = f;

				}
				get: function() {
					return onPurchase;
				}
			});
		};

		this.purchase = function(sku, next) {
			if (typeof next !== "function") {
				logger.debug("WARNING: billing.purchase ignored without a callback");
				return;
			}

			billing.isPurchased(sku, function(owned) {
				if (owned) {
					next("already owned");
				} else {
					// If already waiting for a purchase callback,
					if (purchasing[sku] == 1) {
						onPurchase[sku].push(next);
					} else {
						// We are now purchasing it
						purchasing[sku] = 1;
						onPurchase[sku] = [next];

						// Kick it off
						NATIVE.plugins.sendEvent("BillingPlugin", "purchase", JSON.stringify({
							"sku": sku
						}));
					}
				}
			});
		};

		this.

		this.onOldPurchase = null;

		var purchaseHandler = null;

		this.handleOldPurchases = function(next) {
			if (typeof next !== "function") {
				logger.debug("WARNING: billing.handleOldPurchases ignored without a callback");
				return;
			}

			this.purchaseHandler = 

			// If already got owned list,
			if (gotOwned) {
				// Complete immediately
				next(ownedArray);
			} else {
				if (typeof(next) == "function") {
					// Add to callback list
					onOwned.push(next);
				}
			}
		};
	});

	GLOBAL.billing = new Billing;

	// Wait a couple of seconds to avoid slowing down the startup process
	var ownedRetryID = setTimeout(function() {
		NATIVE.plugins.sendEvent("BillingPlugin", "getPurchases", "{}");
		ownedRetryID = null;
	}, 3000);

	NATIVE.events.registerHandler('billingOwned', function(evt) {
		logger.log("Got billingOwned event:", JSON.stringify(evt));

		if (ownedRetryID !== null) {
			clearTimeout(ownedRetryID);
		}

		// If attempt failed,
		if (evt.failure) {
			ownedRetryID = setTimeout(function() {
				NATIVE.plugins.sendEvent("BillingPlugin", "getPurchases", "{}");
				ownedRetryID = null;
			}, 10000);
		} else {
			// Add owned items
			var skus = evt.skus;
			var tokens = evt.tokens;
			if (skus && skus.length > 0) {
				for (var ii = 0, len = skus.length; ii < len; ++ii) {
					var sku = skus[ii];
					var token = tokens[ii];

					ownedSet[sku] = token;
					tokenSet[token] = sku;
					ownedArray.push(sku);

					// Attempt to consume it immediately
					NATIVE.plugins.sendEvent("BillingPlugin", "consume", JSON.stringify({
						token: token
					}));
				}
			}

			gotOwned = true;
		}
	});

	var isConnected = false;

	NATIVE.events.registerHandler('billingConnected', function(evt) {
		logger.log("Got billingConnected event:", JSON.stringify(evt));

		if (isConnected != evt.connected) {
			GLOBAL.billing.emit("MarketAvailable", isConnected);

			isConnected = evt.connected;

			// If just connected,
			if (isConnected) {
				// If still waiting for owned list
				if (!gotOwned) {
					// Try to get purchases immediately to react faster
					if (ownedRetryID !== null) {
						clearTimeout(ownedRetryID);
					}
					NATIVE.plugins.sendEvent("BillingPlugin", "getPurchases", "{}");
				}
			}
		}
	});
}

