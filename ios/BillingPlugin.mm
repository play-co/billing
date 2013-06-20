#import "BillingPlugin.h"

@implementation BillingPlugin

// The plugin must call super dealloc.
- (void) dealloc {
	if (self.queue != nil) {
		[self.queue removeTransactionObserver:self];
	}

	self.queue = nil;
	self.purchases = nil;

	[super dealloc];
}

// The plugin must call super init.
- (id) init {
	self = [super init];
	if (!self) {
		return nil;
	}

	self.purchases = [NSMutableDictionary dictionary];

	self.queue = [SKPaymentQueue defaultQueue];
	[self.queue addTransactionObserver:self];

	return self;
}

- (void) completeTransaction:(SKPaymentTransaction *)transaction {
	NSString *sku = transaction.payment.productIdentifier;
	NSString *token = transaction.transactionIdentifier;
	
    [self.queue finishTransaction: transaction];
}

- (void) failedTransaction: (SKPaymentTransaction *)transaction {
	NSString *sku = transaction.payment.productIdentifier;

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
										  @"billingConnected",@"name",
										  ([SKPaymentQueue canMakePayments] ? kCFBooleanTrue : kCFBooleanFalse), @"connected",
										  nil]];

    [self.queue finishTransaction: transaction];
}

- (void) paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
	for (SKPaymentTransaction *transaction in transactions) {
		NSString *sku = transaction.payment.productIdentifier;
		NSString *token = transaction.transactionIdentifier;

		switch (transaction.transactionState) {
			case SKPaymentTransactionStatePurchased:
				LOG(@"{billing} Transaction completed purchase for sku=%@ and token=%@", sku, token);
				[self completeTransaction:transaction];
				break;
			case SKPaymentTransactionStateRestored:
				LOG(@"{billing} Transaction restored for sku=%@ and token=%@", sku, token);
				[self completeTransaction:transaction];
				break;
			case SKPaymentTransactionStatePurchasing:
				LOG(@"{billing} Transaction purchasing for sku=%@ and token=%@", sku, token);
				break;
			case SKPaymentTransactionStateFailed:
				LOG(@"{billing} Transaction failed with error code %@ for sku=%@ and token=%@", transaction.error.code, sku, token);
				[self failedTransaction:transaction];
				break;
			default:
				LOG(@"{billing} Unknown transaction error code: %@ for sku=%@ and token=%@", transaction.error.code, sku, token);
				break;
		}

		[[SKPaymentQueue defaultQueue] finishTransaction:transaction];

		[self.inFlight setObject:transaction forKey:transaction.transactionIdentifier];

		js_core *instance = [js_core lastJS];
		
		const char *product = [transaction.payment.productIdentifier UTF8String];
		const char *order = [transaction.transactionIdentifier UTF8String];
		const char *notifyId = order; // Code passed to finishTransaction
		
		// Strip store prefix
		{
			const char *storePrefix = [[instance.config objectForKey:@"bundle_id"] UTF8String];
			unsigned long storePrefixLen = (unsigned long)strlen(storePrefix);
			
			// If prefix matches,
			if (0 == strncmp(storePrefix, product, storePrefixLen)) {
				product += storePrefixLen + 1; // +1 for trailing dot.
			}
		}

		//TODO: USE JANSSON
		static const char *argFormat = "{\"name\":\"purchase\",\"state\":%d,\"product\":\"%s\",\"order\":\"%s\",\"notifyId\":\"%s\"}";
		int argLen = strlen(argFormat) + strlen(product) + strlen(order) + strlen(notifyId) + 20;
		char *args = (char*)malloc(sizeof(char) * argLen);
		snprintf(args, argLen, argFormat, stateCode, product, order, notifyId);
		
		// Run the JavaScript purchase event callback
		{
			jsval vevent[] = { STRING_TO_JSVAL(JS_NewStringCopyZ(instance.cx, args)) };
			[instance dispatchEvent:vevent count:1];
		}
		free(args);
	}
}

- (void) initializeWithManifest:(NSDictionary *)manifest appDelegate:(TeaLeafAppDelegate *)appDelegate {
	NSLOG(@"{billing} Initialized with manifest");
}

- (void) isConnected:(NSDictionary *)jsonObject {
	[[PluginManager get] dispatchJSEvent:[NSDictionary dictionaryWithObjectsAndKeys:
										  @"billingConnected",@"name",
										  ([SKPaymentQueue canMakePayments] ? kCFBooleanTrue : kCFBooleanFalse), @"connected",
										  nil]];
}

- (void) purchase:(NSDictionary *)jsonObject {
	SKPayment *payment = [SKPayment paymentWithProduct:sku];

	[self.queue addPayment:payment];
}

- (void) consume:(NSDictionary *)jsonObject {
	
}

- (void) getPurchases:(NSDictionary *)jsonObject {
	
}

@end
