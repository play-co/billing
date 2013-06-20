#import "PluginManager.h"
#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>


@interface PaymentObserver : UIViewController<SKPaymentTransactionObserver>

@property (nonatomic, retain) NSMutableDictionary *inFlight;
@property (nonatomic) bool hooked;

- (PaymentObserver *) init;

- (void) hookObserver;
- (bool) marketAvailable;
- (void) buy:(NSString *)identifier;
- (void) restore;
- (void) finishTransaction:(NSString *)transaction;

- (void) paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions;

+ (PaymentObserver *) get;
+ (void) shutdown;

@end


@interface BillingPlugin : GCPlugin

- (void) purchase:(NSDictionary *)jsonObject;
- (void) consume:(NSDictionary *)jsonObject;
- (void) getPurchases:(NSDictionary *)jsonObject;

@end
