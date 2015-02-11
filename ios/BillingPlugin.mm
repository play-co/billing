#import "BillingPlugin.h"
#import "platform/log.h"

// TODO: Verify store receipt for security

@implementation BillingPlugin

- (void) dealloc {
	[[SKPaymentQueue defaultQueue] removeTransactionObserver:self];

	self.purchases = nil;
	self.bundleID = nil;
	self.products = nil;
	self.localizedPurchases = nil;
	self.currentPurchaseSku = nil;
	self.invalidProducts = nil;

	[super dealloc];
}

- (id) init {
	self = [super init];
	if (!self) {
		return nil;
	}

	self.purchases = [NSMutableDictionary dictionary];

	[[SKPaymentQueue defaultQueue] addTransactionObserver:self];

	self.bundleID = @"unknown.bundle";

	// store list of all the purchases we know about
	self.products = [NSMutableDictionary dictionary];
	self.localizedPurchases = [NSMutableDictionary dictionary];
	self.invalidProducts = [[NSMutableArray alloc] init];

	// store sku of item that is currently being purchased
	self.currentPurchaseSku = nil;

	return self;
}

- (void) completeTransaction:(SKPaymentTransaction *)transaction {
	NSString *sku = transaction.payment.productIdentifier;
	NSString *token = transaction.transactionIdentifier;
	NSData *receipt = transaction.transactionReceipt;
	NSString *signature = nil;
	if (receipt) {
		signature = [receipt base64EncodedString];
	}

	if ([self.purchases objectForKey:token] != nil) {
		NSLOG(@"{billing} WARNING: Strangeness is afoot.  The same purchase token was specified twice");
	}

	// Remember transaction so that it can be consumed later
	[self.purchases setObject:transaction forKey:token];

	// Strip bundleID prefix
	if ([sku hasPrefix:self.bundleID]) {
		sku = [sku substringFromIndex:([self.bundleID length] + 1)];
	}

	[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
										  @"billingPurchase",@"name",
										  sku, @"sku",
										  token, @"token",
										  signature, @"signature",
										  [NSNull null], @"failure",
										  nil]];

	// clear current purchase
	if ([sku isEqualToString:self.currentPurchaseSku]) {
		self.currentPurchaseSku = nil;
	}
}

- (void) failedTransaction: (SKPaymentTransaction *)transaction {
	NSString *sku = transaction.payment.productIdentifier;

	// Strip bundleID prefix
	if ([sku hasPrefix:self.bundleID]) {
		sku = [sku substringFromIndex:([self.bundleID length] + 1)];
	}

	// clear current purchase
	if ([sku isEqualToString:self.currentPurchaseSku]) {
		self.currentPurchaseSku = nil;
	}

	// Generate error code string
	NSString *errorCode = @"failed";
	switch (transaction.error.code) {
		case SKErrorClientInvalid:
			errorCode = @"client invalid";
			break;
		case SKErrorPaymentCancelled:
			errorCode = @"cancel";
			break;
		case SKErrorPaymentInvalid:
			errorCode = @"payment invalid";
			break;
		case SKErrorPaymentNotAllowed:
			errorCode = @"payment not allowed";
			break;
		case SKErrorStoreProductNotAvailable:
			errorCode = @"item unavailable";
			break;
	}

	[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
										  @"billingPurchase",@"name",
										  sku,@"sku",
										  [NSNull null],@"token",
										  errorCode,@"failure",
										  nil]];

	[[SKPaymentQueue defaultQueue] finishTransaction: transaction];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
	NSLOG(@"{billing} Got products response with %d hits and %d misses", (int)response.products.count, (int)response.invalidProductIdentifiers.count);

	NSString *sku = nil;
	NSUInteger bundleIDIndex = [self.bundleID length] + 1;
	SKProduct *currentProduct = nil;

	NSArray *products = response.products;
	if (products.count > 0) {

		NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
		[numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
		[numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];

		for (SKProduct* product in products) {
			NSLOG(@"{billing} Found product id=%@, title=%@", product.productIdentifier, product.localizedTitle);

			// if this is the current purchase target
			if ([sku isEqualToString:self.currentPurchaseSku]) {
				currentProduct = product;
			}

			// get the formatted price
			[numberFormatter setLocale:product.priceLocale];
			NSString *formattedPrice = [numberFormatter stringFromNumber:product.price];

			// get sku - strip bundle id if possible
			sku = product.productIdentifier;
			if (sku != nil && [sku hasPrefix:self.bundleID]) {
				sku = [sku substringFromIndex:bundleIDIndex];
			}

			// save the product data
			[self.products setObject:product forKey:sku];

			// save localized data
			[self.localizedPurchases setObject:
				[NSDictionary dictionaryWithObjectsAndKeys:
					formattedPrice, @"displayPrice",
					product.localizedTitle, @"title",
					product.localizedDescription, @"description",
					nil
				]
				forKey:sku
			];
		}
	}

	for (NSString *invalidProductId in response.invalidProductIdentifiers) {
		// Add object to invalidProducts list if it's not there
		if ([self.invalidProducts indexOfObject:invalidProductId] == NSNotFound) {
			[self.invalidProducts addObject:invalidProductId];
		}

		NSLOG(@"{billing} Unused product id: %@", invalidProductId);
	}

	// emit a purchasesLocalized event
	[self emitLocalizedPurchases];

	// if currently trying to purchase something
	if (self.currentPurchaseSku != nil) {
		// if we have data for this purchase, start a transaction
		if (currentProduct != nil) {
			SKPayment *payment = [SKPayment paymentWithProduct:currentProduct];
			[[SKPaymentQueue defaultQueue] addPayment:payment];
		} else {
			// Strip bundleID prefix
			sku = self.currentPurchaseSku;
			if (sku != nil && self.bundleID && [sku hasPrefix:self.bundleID]) {
				sku = [sku substringFromIndex:([self.bundleID length] + 1)];
			}

			[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
												  @"billingPurchase",@"name",
												  (sku == nil ? [NSNull null] : sku),@"sku",
												  [NSNull null],@"token",
												  @"invalid product",@"failure",
												  nil]];
		}
	}

	// clear current purchase
	if ([sku isEqualToString:self.currentPurchaseSku]) {
		self.currentPurchaseSku = nil;
	}
}

- (void) paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
	for (SKPaymentTransaction *transaction in transactions) {
		NSString *sku = transaction.payment.productIdentifier;
		NSString *token = transaction.transactionIdentifier;

		switch (transaction.transactionState) {
			case SKPaymentTransactionStatePurchased:
				NSLOG(@"{billing} Transaction completed purchase for sku=%@ and token=%@", sku, token);
				[self completeTransaction:transaction];
				break;
			case SKPaymentTransactionStateRestored:
				NSLOG(@"{billing} Restoring transaction for sku=%@ and token=%@", sku, token);
				[self completeTransaction:transaction];
				break;
			case SKPaymentTransactionStatePurchasing:
				NSLOG(@"{billing} Transaction purchasing for sku=%@ and token=%@", sku, token);
				break;
			case SKPaymentTransactionStateFailed:
				NSLOG(@"{billing} Transaction failed with error code %d(%@) for sku=%@ and token=%@", (int)transaction.error.code, transaction.error.localizedDescription, sku, token);
				[self failedTransaction:transaction];
				break;
			default:
				NSLOG(@"{billing} Ignoring unknown transaction state %d: error=%d for sku=%@ and token=%@", transaction.transactionState, (int)transaction.error.code, sku, token);
				break;
		}

		// clear current purchase
		if ([sku isEqualToString:self.currentPurchaseSku]) {
			self.currentPurchaseSku = nil;
		}
	}
}

- (void) requestPurchase:(NSString *)productIdentifier {
	// This is done exclusively to set up an SKPayment object with the result (it
	// will initiate a purchase)

	NSString *bundledProductId = [self.bundleID stringByAppendingFormat:@".%@", productIdentifier];

	// Create a set with the given identifier
	NSSet *productIdentifiers = [NSSet setWithObjects:productIdentifier,bundledProductId,nil];

	// Create a products request
	SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
	productsRequest.delegate = self;

	// Kick it off!
	[productsRequest start];
}

- (void) initializeWithManifest:(NSDictionary *)manifest appDelegate:(TeaLeafAppDelegate *)appDelegate {
	@try {
		NSDictionary *ios = [manifest valueForKey:@"ios"];
		NSString *bundleID = [ios valueForKey:@"bundleID"];

		self.bundleID = bundleID;

		NSLOG(@"{billing} Initialized with manifest bundleID: '%@'", bundleID);

	}
	@catch (NSException *exception) {
		NSLOG(@"{billing} Failure to get ios:bundleID from manifest file: %@", exception);
	}
}

- (void) isConnected:(NSDictionary *)jsonObject {
	BOOL isMarketAvailable = [SKPaymentQueue canMakePayments];

	NSLOG(@"{billing} Responded with Market Available: %@", isMarketAvailable ? @"YES" : @"NO");

	[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
										  @"billingConnected",@"name",
										  (isMarketAvailable ? kCFBooleanTrue : kCFBooleanFalse), @"connected",
										  nil]];
}

- (void) purchase:(NSDictionary *)jsonObject {
	NSString *sku = nil;

	@try {
		sku = [jsonObject valueForKey:@"sku"];

		// if we already have product data for this item id, start purchase
		SKProduct *product = [self.products valueForKey:sku];
		if (product != nil) {
			NSLOG(@"{billing} already have data for %@, starting purchase", sku);
			SKPayment *payment = [SKPayment paymentWithProduct:product];
			[[SKPaymentQueue defaultQueue] addPayment:payment];
		} else {
			// otherwise, check with the store first
			NSLOG(@"{billing} no product data for %@, querying store", sku);
			self.currentPurchaseSku = sku;
			[self requestPurchase:sku];
		}
	}
	@catch (NSException *exception) {
		NSLOG(@"{billing} WARNING: Unable to purchase item: %@", exception);

		[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
											  @"billingPurchase",@"name",
											  sku ? sku : [NSNull null],@"sku",
											  [NSNull null],@"token",
											  @"failed",@"failure",
											  nil]];
	}
}

- (void) consume:(NSDictionary *)jsonObject {
	NSString *token = nil;

	@try {
		token = [jsonObject valueForKey:@"token"];

		SKPaymentTransaction *transaction = [self.purchases valueForKey:token];
		if (!transaction) {
			NSLOG(@"{billing} Failure consuming item with unknown token: %@", token);

			[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
												  @"billingConsume",@"name",
												  token,@"token",
												  @"already consumed",@"failure",
												  nil]];
		} else {
			NSLOG(@"{billing} Consuming: %@", token);

			[self.purchases removeObjectForKey:token];

			[[SKPaymentQueue defaultQueue] finishTransaction:transaction];

			// TODO: If something fails at this point the player will lose their purchase.

			[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
												  @"billingConsume",@"name",
												  token,@"token",
												  [NSNull null],@"failure",
												  nil]];
		}
	}
	@catch (NSException *exception) {
		NSLOG(@"{billing} WARNING: Unable to consume item: %@", exception);

		[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
											  @"billingConsume",@"name",
											  token ? token : [NSNull null],@"token",
											  @"failed",@"failure",
											  nil]];
	}
}

- (void) getPurchases:(NSDictionary *)jsonObject {
	// Send the list of purchases that may have been missed by the JavaScript during startup
	@try {
		NSMutableArray *skus = [NSMutableArray array];
		NSMutableArray *tokens = [NSMutableArray array];
		NSMutableArray *signatures = [NSMutableArray array];

		for (NSString *token in self.purchases) {
			SKPaymentTransaction *transaction = [self.purchases objectForKey:token];
			NSString *sku = transaction.payment.productIdentifier;
			NSData *receipt = transaction.transactionReceipt;
			NSString *signature = nil;
			if (receipt) {
				signature = [receipt base64EncodedString];
			}

			[skus addObject:sku];
			[tokens addObject:token];
			[signatures addObject:signature];
		}

		NSLOG(@"{billing} Notifying wrapper of %d existing purchases", (int)[skus count]);

		[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
											  @"billingOwned",@"name",
											  skus,@"skus",
											  tokens,@"tokens",
											  signatures,@"signatures",
											  [NSNull null],@"failure",
											  nil]];
	}
	@catch (NSException *exception) {
		NSLOG(@"{billing} WARNING: Unable to get purchases: %@", exception);
		[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
											  @"billingOwned",@"name",
											  [NSNull null],@"skus",
											  [NSNull null],@"tokens",
											  @"failed",@"failure",
											  nil]];
	}
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
	[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
										  @"billingRestore",@"name",
										  error,@"failure",
										  nil]];
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
	[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
										  @"billingRestore",@"name",
										  [NSNull null],@"failure",
										  nil]];
}

- (void) restoreCompleted:(NSDictionary *)jsonObject {
	// Send the list of purchases that may have been missed by the JavaScript during startup
	@try {
		[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];

		NSLOG(@"{billing} Restoring completed transactions");
	}
	@catch (NSException *exception) {
		NSLOG(@"{billing} WARNING: Unable to restore completed: %@", exception);
		[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
											  @"billingRestore",@"name",
											  exception,@"failure",
											  nil]];
	}
}

- (void) localizePurchases:(NSDictionary *)jsonObject {
	NSString *bundledProductId;
	NSMutableSet *products = [[NSMutableSet alloc] init];

	// go through all the requested items and add to the products set
	// with and without the bundleID added (to match existing code)
	id items = [jsonObject valueForKey:@"items"];
	NSString* productPrefix = [self.bundleID stringByAppendindString:@"."];
	for (id key in items) {
		if ([key hasPrefix:bundledProductId]) {
			[products addObject:key];
		} else {
			[products addObject:[self.bundleID stringByAppendingFormat:@".%@", key]];
		}
	}

	// create productsrequest and set self as delegate
	NSSet *productIdentifiers = [NSSet setWithSet: (NSSet *)products];
	SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];
	productsRequest.delegate = self;

	// start the request
	[productsRequest start];
}

- (void) emitLocalizedPurchases {
	// restructure into a bunch of lists to match existing getPurchases API

	NSMutableArray *skus = [NSMutableArray array];
	NSMutableArray *titles = [NSMutableArray array];
	NSMutableArray *descriptions = [NSMutableArray array];
	NSMutableArray *displayPrices = [NSMutableArray array];

	for (NSString *sku in self.localizedPurchases) {
		NSDictionary *purchase = [self.localizedPurchases objectForKey:sku];

		[skus addObject:sku];
		[titles addObject:[purchase valueForKey:@"title"]];
		[descriptions addObject:[purchase valueForKey:@"description"]];
		[displayPrices addObject:[purchase valueForKey:@"displayPrice"]];
	}

	[[PluginManager get] dispatchJSEvent:@{
		@"name": @"purchasesLocalized",
		@"skus": skus,
		@"titles": titles,
		@"descriptions": descriptions,
		@"displayPrices": displayPrices,
		@"invalidProductIdentifiers": self.invalidProducts
	}];
}

@end
