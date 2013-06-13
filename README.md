# Game Closure DevKit Plugin: Billing

## Usage

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
files that offers a few new API functions:

# Class: billing

## Methods

### billing.purchase (sku, next)

Parameters
:    1. `sku {string}` ---The product SKU.
     2. `callback {function}` ---The callback function.  First argument will be
a string describing the failure reason if the purchase attempt failed.

Returns
:    1. `void`

Initiate the purchase of an item by its SKU.

The purchase may fail if the user clicks to deny the purchase, or if the user
has already purchased the item.

Callback argument values:

+ null : Purchase success.
+ "already owned" : User has already purchased the item.
+ "failed" : Was not able to make purchase request.
+ "cancel" : User canceled the purchase or item was unavailable.

~~~
billing.purchase("android.test.purchased", function(fail) {
	if (fail) {
		logger.log("~~~ PURCHASE FAILED:", fail);
	} else {
		logger.log("~~~ PURCHASE SUCCESS");
	}
});
~~~

### billing.getPurchases (next)

Parameters
:    1. `callback {function}` ---The callback function.  First argument will be
an array of SKU strings for all of the prior purchases.

Returns
:    1. `void`

Gets the list of purchased item SKUs.

~~~
billing.getPurchases(function(skus) {
	logger.log("~~~ PRIOR PURCHASES:");
	for (var ii = 0; ii < skus.length; ++ii) {
		var sku = skus[ii];
		logger.log(sku);
	}
});
~~~

### billing.isPurchased (sku, next)

Parameters
:    1. `sku {string}` ---The product SKU.
     2. `callback {function}` ---The callback function.  First argument will be
truthy if the SKU was already purchased, and false if it was not.

Returns
:    1. `void`

Checks if an item is already purchased or not by referencing its SKU string.

### billing.consume (sku, next)

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
+ "not owned" : User has not purchased this item yet.
+ "failed" : Was not able to make consume request.
+ "cancel" : User canceled the consumption or item was unavailable.

