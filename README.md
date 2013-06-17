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
import plugins.billing.install;
~~~

This installs a new global `billing` object accessible to all of your source.

## Checking for Market Availability

Billing supports in-app purchases from the Google Play Store on Android, and from
the Apple App Store on iOS.

Purchases can fail to go through due to network failures or market unavailability.  You can verify that the market is available by checking `billing.isMarketAvailable` before displaying your in-app store.  You can also subscribe to a "MarketAvailable" event (see event documentation below).

~~~
// In response to player clicking store button:

if (!billing.isMarketAvailable) {
	// Market is unavailable - User should turn off Airplane mode or find reception.
}
~~~

## Making Purchases

To simplify the API, all purchases are handled as consumables.  For this reason,
it is up to you to make sure that players do not purchase ie. character unlocks
two times as the billing plugin cannot differentiate those types of one-time
upgrade -style purchases from consumable currency -style purchases.

~~~
// Initialize the coin counter
var coinCount = localStorage.getItem("coinCount") || 0;

// In response to player clicking the "5 coin purchase" button:

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

After a player successfully purchases an item, it is a good idea to store it in
offline local storage to persist between runs of the game.  This can be done
with the normal HTML5 localStorage API as shown above.

## Handling Prior Purchases

On startup, after loading the coin counts and other credits from local storage,
you should query the list of outstanding purchases.  These items were bought
before the game closed and still need to be credited in-game.

Handling this properly will avoid problems where your players bought an item
but never got credited for it.

~~~
// After reading the coinCount on startup:

billing.handleOldPurchases(function(items) {
	var handlers = {
		"fiveCoins": function() {
			// Update the visual coin counter here.
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

This callback may complete at any time when the market becomes available, even during gameplay.

# Global Object: billing

## Events

### "MarketAvailable"

This event fires whenever market availability changes.

~~~
billing.on('MarketAvailable', function (available) {
	if (available) {
	} else {
	}
});
~~~

Read the [event system documentation](http://docs.gameclosure.com/api/event.html)
for other ways to handle these events.

## Members

### billing.isMarketAvailable

+ `boolean` ---True when market is available.

The market can become unreachable when network service is interrupted or if
the mobile device enters Airplane mode.

~~~
if (billing.isMarketAvailable) {
	logger.log("~~~ MARKET IS AVAILABLE");
} else {
	logger.log("~~~ MARKET IS NOT AVAILABLE");
}
~~~

## Methods

### billing.purchase (itemName, next(fail))

Parameters
:    1. `itemName {string}` ---The item name string.
     2. `callback {function}` ---The callback function.  First argument will be
a string describing the failure reason if the purchase attempt failed.

Returns
:    1. `void`

Initiate the purchase of an item by its SKU.

The purchase may fail if the player clicks to deny the purchase, or if the user
has already purchased the item, or if the network is unavailable, as examples.

Failure values:

+ null : Purchase success.
+ "service" : Not connected to the Market.  Try again later.
+ "cancel" : User canceled the purchase or item was unavailable.
+ Other Reasons : Was not able to make purchase request for some other reason.

~~~
billing.purchase("android.test.purchased", function(fail) {
	if (fail) {
		logger.log("~~~ PURCHASE FAILED:", fail);
	} else {
		logger.log("~~~ PURCHASE SUCCESS");
	}
});
~~~

### billing.handleOldPurchases (next(itemNames))

Parameters
:    1. `callback {function}` ---The callback function.
			The first argument will be an array of item name strings for all of the prior purchases.

Returns
:    1. `void`

Gets the list of purchased item SKUs.  These are outstanding from previous
purchases but have not been credited to the player yet.

WARNING: This function may complete at any time as the market becomes available.

The handler should be resilient and work regardless of what state the game is in.
For instance, the callback function should not pop up the purchase success
dialog while they are playing.

~~~
billing.handleOldPurchases(function(itemNames) {
	for (var ii = 0; ii < items.length; ++ii) {
		var itemName = itemNames[ii];

		logger.log("~~~ PRIOR PURCHASE:", itemName);
	}
});
~~~

