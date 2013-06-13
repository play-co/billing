# Game Closure DevKit Plugin: Billing

## Installation

Install the billing plugin by running `basil install billing`.

Include it in the `manifest.json` file under the "addons" section for your game:

~~~
"addons": [
	"billing"
],
~~~

At the top of your `src/Application.js` install the JS wrapper:

~~~
import plugins.billing.install as Billing;
~~~

This installs a new global `billing` object accessible from all of your source
files that offers a few new API functions (see below).

## Checking for Market Availability

Billing supports in-app purchases on the Google Play Store on Android, and on
the Apple App Store on iOS.

Purchases can fail due to network failures or the user canceling the purchase,
as examples.  You can check if the market is available by checking
`billing.isMarketAvailable` before displaying the in-app store.  You can also
subscribe to a "MarketAvailable" event (see event documentation below).

~~~
// In response to user clicking store button:

if (billing.isMarketAvailable) {
	// Market is unavailable - User should turn off Airplane mode or find reception.
}
~~~

## Making Purchases

To simplify the API, all purchases are handled as consumables.  For this reason,
it is up to you to make sure that users do not purchase ie. character unlocks
twice as the billing plugin cannot differentiate those types of purchases from
in-game currency purchases.

~~~
// Initialize the coin counter
var coinCount = localStorage.getItem("coinCount") || 0;

// In response to user clicking the "5 coin purchase" button:

billing.purchase("fiveCoins", function(fail) {
	if (!fail) {
		// Update the visual coin counter here.
		coinCount += 5;
		localStorage.setItem("coinCount", coinCount);

	} else if (fail === "service") {
		// Market is unavailable - User should turn off Airplane mode or find reception.

	} else if (fail !== "cancel") {
		// Item purchase failed for some other reason, maybe a network failure.
	}
	// Else: Item purchase canceled - No need to present a dialog in response.
});
~~~

After a user successfully purchases an item, it is a good idea to store it in
offline local storage.  This can be done with the normal HTML5 localStorage API
as shown above.

## Handling Prior Purchases

On startup, after loading the coin counts and other credits from local storage,
you should query the list of outstanding purchases.  These items were bought
before the game closed and still need to be credited in-game.

Handling this properly will prevent most problems where your users bought an
item but never got credited for it in the game.

~~~
// After reading the coinCount on startup:

billing.onOldPurchases(function(items) {
	var handlers = {
		"fiveCoins": function() {
			coinCount += 5;
			localStorage.setItem("coinCount", coinCount);
		}
	};

	for (var ii = 0; ii < items; ++ii) {
		var item = items[ii];
		if (typeof handlers[item] === "function") {
			handlers[item]();
		}
	}
});
~~~

# Global Object: billing

## Events

### "MarketAvailable"

This event fires whenever the market state changes.

~~~
billing.on('MarketAvailable', function (available) {
	if (available) {
	} else {
	}
});
~~~

To listen for the first time the market becomes available:

~~~
var MarketChecker = function(available) {
	if (available) {
		// Market is available.
	} else {
		billing.once('MarketAvailable', MarketChecker);
	}
}

MarketChecker(false); // Install
~~~

Read the [event system documentation](http://docs.gameclosure.com/api/event.html)
for other ways to handle these events.

### "PurchasesDownloaded"

This event fires whenever the purchased list has been downloaded from the market.
It provides an array of item SKU strings for the purchased items.

This event only fires once and may happen earlier than you install a listener
for it, so it would be a good idea to also check the billing.isDownloaded as in
this example:

~~~
var OnPurchases(skusArray, skusSet) {
	if (skusSet["fiveCoins"]) {
	}
}

if (billing.isDownloaded) {
} else {
}
billing.on('PurchasesDownloaded', function (skus) {
	for (var ii = 0; ii < skus.length; ++ii) {
	}
});
~~~

## Members

### billing.isMarketAvailable

+ `boolean` ---True when market is available.

The market can become unreachable when network service is interrupted or if
the mobile user enters Airplane mode.

~~~
if (billing.isMarketAvailable) {
	logger.log("~~~ MARKET IS AVAILABLE");
} else {
	logger.log("~~~ MARKET IS NOT AVAILABLE");
}
~~~

## Methods

### billing.purchase (sku, next(fail))

Parameters
:    1. `sku {string}` ---The product SKU.
     2. `callback {function}` ---The callback function.  First argument will be
a string describing the failure reason if the purchase attempt failed.

Returns
:    1. `void`

Initiate the purchase of an item by its SKU.

The purchase may fail if the user clicks to deny the purchase, or if the user
has already purchased the item, or if the network is unavailable, as examples.

Failure values:

+ null : Purchase success.
+ "service" : Not connected to the Market.  Try again later.
+ "owned" : User has already purchased the item.
+ "cancel" : User canceled the purchase or item was unavailable.
+ "fail" : Was not able to make purchase request.  Maybe disconnected.

~~~
billing.purchase("android.test.purchased", function(fail) {
	if (fail) {
		logger.log("~~~ PURCHASE FAILED:", fail);
	} else {
		logger.log("~~~ PURCHASE SUCCESS");
	}
});
~~~

### billing.getPurchases (next(fail, skus))

Parameters
:    1. `callback {function}` ---The callback function.
			The first argument will be null on success, or it will be a string describing the failure.
			The second argument will be an array of SKU strings for all of the prior purchases.

Returns
:    1. `void`

Gets the list of purchased item SKUs.

Failure values:

+ null : Purchase success.
+ "service" : Not connected to the Market.  Try again later.

~~~
billing.getPurchases(function(fail, skus) {
	if (fail) {
		logger.log("~~~ UNABLE TO GET PRIOR PURHCASES:", fail);
	} else {
		logger.log("~~~ PRIOR PURCHASES:");
		for (var ii = 0; ii < skus.length; ++ii) {
			var sku = skus[ii];

			logger.log(sku);
		}
	}
});
~~~

### billing.isPurchased (sku, next(fail, purchased))

Parameters
:    1. `sku {string}` ---The product SKU.
     2. `callback {function}` ---The callback function.
			The first argument will be null on success, or it will be a string describing the failure.
	 		The second argument will be truthy if the SKU was already purchased, and false if it was not.

Returns
:    1. `void`

Checks if an item is already purchased or not by referencing its SKU string.

~~~
billing.isPurchased("android.test.purchased", function(purchased, fail) {
	if (fail) {
		logger.log("~~~ UNABLE TO GET PURCHASE INFO:", fail);
	} else {
		if (purchased) {
			logger.log("~~~ ITEM WAS PURCHASED");
		} else {
			logger.log("~~~ ITEM NOT PURCHASED");
		}
	}
});
~~~

### billing.consume (sku, next(fail))

Parameters
:    1. `sku {string}` ---The product SKU.
     2. `callback {function}` ---The callback function.  First argument will be
null if the consumption completed successfully, otherwise it will be a string
that explains why it could not be consumed.

Returns
:    1. `void`

Consumes a previously purchased item.

Callback argument values:

+ null : Purchase success.
+ "unowned" : User has not purchased this item yet.
+ "consuming" : A request to consume this item is already outstanding.
+ "fail" : Was not able to make consume request.

~~~
billing.consume("android.test.purchased", function(fail) {
	if (fail) {
		logger.log("~~~ UNABLE TO CONSUME:", fail);
	} else {
		logger.log("~~~ ITEM CONSUMED");
	}
});
~~~

