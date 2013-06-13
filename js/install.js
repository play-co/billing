import device;

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

	NATIVE.events.registerHandler('billingPurchase', function(evt) {
		logger.log("Got billingPurchase event");

		// NOTE: Function is organized carefully for callback reentrancy

		var sku = evt.sku;

		// If not failed,
		if (!evt.failure) {
			// Mark it owned
			ownedSet[sku] = 1;
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
		purchasing[sku] = 0;
	});

	NATIVE.events.registerHandler('billingOwned', function(evt) {
		logger.log("Got billingOwned event");

		// Add owned items
		var skus = evt.skus;
		if (skus && skus.length > 0) {
			for (var ii = 0, len = skus.length; ii < len; ++ii) {
				var sku = skus[ii];

				ownedSet[sku] = 1;
				ownedArray.push(sku);
			}
		}

		gotOwned = true;

		// Call owned callbacks
		for (var ii = 0; ii < onOwned.length; ++ii) {
			onOwned[ii](ownedArray);
		}
		onOwned.length = 0;
	});

	GLOBAL.billing = {
		isPurchased: function(sku, next) {
			if (typeof(next) == "function") {
				// If already got owned list,
				if (gotOwned) {
					// Complete immediately
					next(ownedSet[sku] == 1);
				} else {
					// Add to callback list
					onOwned.push(function() {
						next(ownedSet[sku] == 1);
					});
				}
			}
		},
		purchase: function(sku, next) {
			billing.isPurchased(sku, function(owned) {
				if (owned) {
					next("already owned");
				} else {
					// If already waiting for a purchase callback,
					if (purchasing[sku] == 1) {
						if (typeof(next) == "function") {
							if (onPurchase[sku]) {
								onPurchase[sku].push(next);
							} else {
								onPurchase[sku] = [next];
							}
						}
					} else {
						// We are now purchasing it
						purchasing[sku] = 1;

						if (typeof(next) == "function") {
							onPurchase[sku] = [next];
						}

						// Kick it off
						NATIVE.plugins.sendEvent("BillingPlugin", "purchase", JSON.stringify({
							"sku": sku
						}));
					}
				}
			});
		},
		getPurchases: function(next) {
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
		}
	}

	NATIVE.plugins.sendEvent("BillingPlugin", "getPurchases", "{}");
}

