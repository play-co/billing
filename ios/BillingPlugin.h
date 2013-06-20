#import "PluginManager.h"
#import <StoreKit/StoreKit.h>

@interface BillingPlugin : GCPlugin<SKPaymentTransactionObserver>

@property (nonatomic, retain) SKPaymentQueue *queue;
@property (nonatomic, retain) NSMutableDictionary *purchases;

- (void) paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions;

- (void) isConnected:(NSDictionary *)jsonObject;
- (void) purchase:(NSDictionary *)jsonObject;
- (void) consume:(NSDictionary *)jsonObject;
- (void) getPurchases:(NSDictionary *)jsonObject;

@end
