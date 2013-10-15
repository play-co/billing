# Game Closure DevKit Plugin: Billing

The billing plugin supports in-app purchases from the Google Play Store on Android, and from the Apple App Store on iOS, through one simple unified API.

## Installation

Install the billing plugin by running `basil install billing`.

Include it in the `manifest.json` file under the "addons" section for your game:

~~~
"addons": [
	"billing"
],
~~~

You can import the billing object anywhere in your application:

~~~
import plugins.billing.billing as billing;
~~~


### iOS Setup

For iOS you should ensure that your game's `manifest.json` has the correct "bundleID", "appleID", and "version" fields.

The store item Product IDs must be prefixed with your bundleID (as in "com.gameshop.sword"), but you should refer to the item as "sword" in your JavaScript code.

All store items should be set up as Consumable.

After building your game, you will need to turn on the IAP entitlement.  This can be done by selecting your project, choosing the "Capabilities" tab, and turning on the In-App Purchase entitlement.  You will be prompted to log in to your development team.

## Handling Purchases

In the JavaScript code for your game, you should write some code to handle in-app purchases.  After reading the previous state of the purchasable items from `localStorage`, your code should set up a `billing.onPurchase` handler:

~~~
// Initialize the coin counter
var coinCount = localStorage.getItem("coinCount") || 0;

var purchaseHandlers = {
	"fiveCoins": function() {
		// Update the visual coin counter here.
		coinCount += 5;
		localStorage.setItem("coinCount", coinCount);
		// Pop-up award modal here.
	}
};

function handlePurchase(item) {
	var handler = purchaseHandlers[item];
	if (typeof handler === "function") {
		handler();
	}
};

billing.onPurchase = handlePurchase;
~~~

The callback you set for `billing.onPurchase` is only called on successful purchases.  It will be called once for each purchase that should be credited to the player.  Purchases will be queued up until the callback is set, and then they will all be delivered, one at a time.

After a player successfully purchases an item, it is a good idea to store it in
offline local storage to persist between runs of the game.  This can be done
with the normal HTML5 localStorage API as shown above.

## Handling Purchase Failures

When purchases fail, the failure may be handled with the `billing.onFailure` callback:

~~~
function handleFailure(reason, item) {
	if (reason !== "cancel") {
		// Market is unavailable - User should turn off Airplane mode or find reception.
	}

	// Else: Item purchase canceled - No need to present a dialog in response.
}

billing.onFailure = handleFailure;
~~~

Handling these failures is *optional*.

One way to respond is to pop up a modal dialog that says "please check that Airplane mode is disabled and try again later."  It may also be interesting to do some analytics on how often users cancel purchases or fail to make purchases.

## Checking for Market Availability

Purchases can fail to go through due to network failures or market unavailability.  You can verify that the market is available by checking `billing.isMarketAvailable` before displaying your in-app store.  You can also subscribe to a "MarketAvailable" event (see event documentation below).

~~~
// In response to player clicking In-App Store button:

if (!billing.isMarketAvailable) {
	// Market is unavailable - User should turn off Airplane mode or find reception.
}
~~~

Checking for availability is entirely optional.

## Requesting Purchases

All purchases are handled as consumables.  For this reason, it is up to you to make sure that players do not purchase ie. character unlocks two times as the billing plugin cannot differentiate those types of one-time upgrade -style purchases from consumable currency -style purchases.

When you request a purchase, a system modal will pop up that the user will interact with and may cancel.  Purchases may also fail for other reasons such as network outages.

Kicking off a new purchase is done with the `billing.purchase` function:

~~~
// In response to player clicking the "5 coin purchase" button:

billing.purchase("fiveCoins");
~~~

## Disabling Purchases

The purchase callback may happen at any time, even during gameplay.  So it is a good idea to disable the callback when it is inopportune by setting it to null.  When you want to receive the callback events, just set it back to the handler and any queued events will be delivered as shown in this example code:

~~~
// When player enters game and should not be disturbed by purchase callbacks:
function DisablePurchaseEvents() {
	billing.onPurchase = null;
	billing.onFailure = null;
}

// And when they return to the menu system:
function EnablePurchaseEvents() {
	billing.onPurchase = handlePurchase; // see definitions in examples above
	billing.onFailure = handleFailure;
}
~~~

# billing object

## Events

### "MarketAvailable"

This event fires whenever market availability changes.  It is safe to ignore these events.

~~~
billing.on('MarketAvailable', function (available) {
	if (available) {
	} else {
	}
});
~~~

Read the [event system documentation](http://docs.gameclosure.com/api/event.html)
for other ways to handle these events.

## Members:

### billing.isMarketAvailable

+ `boolean` ---True when market is available.

The market can become unreachable when network service is interrupted or if
the mobile device enters Airplane mode.

It is safe to disregard this flag.

~~~
if (billing.isMarketAvailable) {
	logger.log("~~~ MARKET IS AVAILABLE");
} else {
	logger.log("~~~ MARKET IS NOT AVAILABLE");
}
~~~

### billing.onPurchase (itemName)

+ `callback {function}` ---Set to your callback function.
			The first argument will be the name of the item that should be credited to the player.

Called whenever a purchase completes.  This may also be called for a purchase that was outstanding from a previous session that had not been credited to the player yet.

The callback function should not pop up the purchase success dialog while they are playing.  Setting the `billing.onPurchase` callback to **null** when purchases should not interrupt gameplay is recommended.

~~~
billing.onPurchase = function(itemName) {
	logger.log("~~~ PURCHASED:", itemName);
});
~~~

### billing.onFailure (reason, itemName)

+ `callback {function}` ---Set to your callback function.
			The first argument will be the reason for the failure.
			The second argument will be the name of the item that was requested.  Sometimes the name will be `null`.

Unlike the success callback, failures are not queued up for delivery.  When failures are not handled they are not reported.

The `itemName` argument to the callback is not reliable.  Sometimes it will be `null`.

Handling failure events is optional.

Common failure values:

+ "cancel" : User canceled the purchase or item was unavailable.
+ "service" : Not connected to the Market.  Try again later.
+ Other Reasons : Was not able to make purchase request for some other reason.

## Methods:

### billing.purchase (itemName, [simulate])

Parameters
:	1. `itemName {string}` ---The item name string.
	2. `[simulate {string}]` ---Optional simulation mode: `undefined` means disabled. "simulate" means simulate a successful purchase.  Any other value will be used as a simulated failure string.

Returns
:    1. `void`

Initiate the purchase of an item by its name.

The purchase may fail if the player clicks to deny the purchase, or if the network is unavailable, among other reasons.  If the purchase fails, the `billing.onFailure` handler will be called.  Handling failures is optional.

If the purchase succeeds, then the `billing.onPurchase` callback you set will be called.  This callback should be where you credit the user for the purchase.

~~~
billing.purchase("fiveCoins");
~~~

##### Simulation Mode

To test purchases without hitting the market, pass a second parameter of "simulate" or "cancel".  On browser builds or in the web simulator, purchases will always simulate success otherwise.

~~~
billing.purchase("fiveCoins", "simulate"); // Simulates success
billing.purchase("fiveCoins", "cancel"); // Simulates failure "cancel"
~~~
