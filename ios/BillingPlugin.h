#import "PluginManager.h"
#import "NSData+Base64.h"
#import <StoreKit/StoreKit.h>

@interface BillingPlugin : GCPlugin<SKPaymentTransactionObserver, SKProductsRequestDelegate>

@property (nonatomic, retain) NSMutableDictionary *purchases;
@property (nonatomic, retain) NSString *bundleID;
@property (nonatomic, retain) NSMutableDictionary *products;
@property (nonatomic, retain) NSMutableDictionary *localizedPurchases;
@property (nonatomic, retain) NSMutableArray *invalidProducts;
@property (nonatomic, retain) NSString *currentPurchaseSku;

- (void) paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions;

- (void) requestPurchase:(NSString *)productIdentifier;

- (void) isConnected:(NSDictionary *)jsonObject;
- (void) purchase:(NSDictionary *)jsonObject;
- (void) consume:(NSDictionary *)jsonObject;
- (void) getPurchases:(NSDictionary *)jsonObject;
- (void) localizePurchases:(NSDictionary *)jsonObject;

@end
