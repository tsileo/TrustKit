/*
 
 TSKPinningValidatorTests.m
 TrustKit
 
 Copyright 2015 The TrustKit Project Authors
 Licensed under the MIT license, see associated LICENSE file for terms.
 See AUTHORS file for the list of project authors.
 
 */

#import <XCTest/XCTest.h>
#import "TrustKit+Private.h"
#import "ssl_pin_verifier.h"
#import "public_key_utils.h"
#import "TSKCertificateUtils.h"


@interface TSKPinningValidatorTests : XCTestCase
{
    
}
@end

@implementation TSKPinningValidatorTests
{
    SecCertificateRef _rootCertificate;
    SecCertificateRef _intermediateCertificate;
    SecCertificateRef _selfSignedCertificate;
    SecCertificateRef _leafCertificate;
}


- (void)setUp
{
    [super setUp];
    // Create our certificate objects
    _rootCertificate = [TSKCertificateUtils createCertificateFromDer:@"GoodRootCA"];
    _intermediateCertificate = [TSKCertificateUtils createCertificateFromDer:@"GoodIntermediateCA"];
    _leafCertificate = [TSKCertificateUtils createCertificateFromDer:@"www.good.com"];
    _selfSignedCertificate = [TSKCertificateUtils createCertificateFromDer:@"www.good.com.selfsigned"];
    
    [TrustKit resetConfiguration];
}


- (void)tearDown
{
    CFRelease(_rootCertificate);
    CFRelease(_intermediateCertificate);
    CFRelease(_leafCertificate);
    [super tearDown];
}


// Pin to any of CA, Intermediate CA and Leaf certificates public keys (all valid) and ensure it succeeds
- (void)testVerifyAgainstAnyPublicKey
{
    // Create a valid server trust
    SecCertificateRef certChainArray[2] = {_leafCertificate, _intermediateCertificate};
    SecCertificateRef trustStoreArray[1] = {_rootCertificate};
    SecTrustRef trust = [TSKCertificateUtils createTrustWithCertificates:(const void **)certChainArray
                                                             arrayLength:sizeof(certChainArray)/sizeof(certChainArray[0])
                                                      anchorCertificates:(const void **)trustStoreArray
                                                             arrayLength:sizeof(trustStoreArray)/sizeof(trustStoreArray[0])];
    
    // Create a configuration
    NSDictionary *trustKitConfig = @{kTSKPinnedDomains :
                                         @{@"www.good.com" : @{
                                                   kTSKPublicKeyAlgorithms : @[kTSKAlgorithmRsa4096],
                                                   kTSKPublicKeyHashes : @[@"TQEtdMbmwFgYUifM4LDF+xgEtd0z69mPGmkp014d6ZY=", // Server key
                                                                           @"khKI6ae4micEvX74MB/BZ4u15WCWGXPD6Gjg6iIRVeE=", // Intermediate key
                                                                           @"iQMk4onrJJz/nwW1wCUR0Ycsh3omhbM+PqMEwNof/K0=" // CA key
                                                                           ]}}};
    
    // First test the verifyPublicKeyPin() function
    NSDictionary *parsedTrustKitConfig = parseTrustKitArguments(trustKitConfig);
    
    TSKPinValidationResult verificationResult = TSKPinValidationResultFailed;
    verificationResult = verifyPublicKeyPin(trust,
                                            @"www.good.com",
                                            parsedTrustKitConfig[kTSKPinnedDomains][@"www.good.com"][kTSKPublicKeyAlgorithms],
                                            parsedTrustKitConfig[kTSKPinnedDomains][@"www.good.com"][kTSKPublicKeyHashes]);
    
    
    XCTAssert(verificationResult == TSKPinValidationResultSuccess, @"Validation must pass against valid public key pins");
    
    
    
    // Then test TSKPinningValidator
    [TrustKit initializeWithConfiguration:trustKitConfig];
    XCTAssert([TSKPinningValidator evaluateTrust:trust forHostname:@"www.good.com"] == TSKTrustDecisionShouldAllowConnection);
    
    CFRelease(trust);
}


// Pin only to the Intermediate CA certificate public key and ensure it succeeds
- (void)testVerifyAgainstIntermediateCAPublicKey
{
    // Create a valid server trust
    SecCertificateRef certChainArray[2] = {_leafCertificate, _intermediateCertificate};
    SecCertificateRef trustStoreArray[1] = {_rootCertificate};
    SecTrustRef trust = [TSKCertificateUtils createTrustWithCertificates:(const void **)certChainArray
                                                             arrayLength:sizeof(certChainArray)/sizeof(certChainArray[0])
                                                      anchorCertificates:(const void **)trustStoreArray
                                                             arrayLength:sizeof(trustStoreArray)/sizeof(trustStoreArray[0])];
    
    // Create a configuration
    NSDictionary *trustKitConfig = @{kTSKPinnedDomains :
                                         @{@"www.good.com" : @{
                                                   kTSKPublicKeyAlgorithms : @[kTSKAlgorithmRsa4096],
                                                   kTSKPublicKeyHashes : @[@"khKI6ae4micEvX74MB/BZ4u15WCWGXPD6Gjg6iIRVeE=", // Intermediate Key
                                                                           @"khKI6ae4micEvX74MB/BZ4u15WCWGXPD6Gjg6iIRVeE=" // Intermediate Key
                                                                           ]}}};
    
    // First test the verifyPublicKeyPin() function
    NSDictionary *parsedTrustKitConfig = parseTrustKitArguments(trustKitConfig);
    
    TSKPinValidationResult verificationResult = TSKPinValidationResultFailed;
    verificationResult = verifyPublicKeyPin(trust,
                                            @"www.good.com",
                                            parsedTrustKitConfig[kTSKPinnedDomains][@"www.good.com"][kTSKPublicKeyAlgorithms],
                                            parsedTrustKitConfig[kTSKPinnedDomains][@"www.good.com"][kTSKPublicKeyHashes]);
    
    
    XCTAssert(verificationResult == TSKPinValidationResultSuccess, @"Validation must pass against valid public key pins");
    
    
    // Then test TSKPinningValidator
    [TrustKit initializeWithConfiguration:trustKitConfig];
    XCTAssert([TSKPinningValidator evaluateTrust:trust forHostname:@"www.good.com"] == TSKTrustDecisionShouldAllowConnection);
    CFRelease(trust);
}


// Pin only to the CA certificate public key and ensure it succeeds
- (void)testVerifyAgainstCAPublicKey
{
    // Create a valid server trust
    SecCertificateRef certChainArray[2] = {_leafCertificate, _intermediateCertificate};
    SecCertificateRef trustStoreArray[1] = {_rootCertificate};
    SecTrustRef trust = [TSKCertificateUtils createTrustWithCertificates:(const void **)certChainArray
                                                             arrayLength:sizeof(certChainArray)/sizeof(certChainArray[0])
                                                      anchorCertificates:(const void **)trustStoreArray
                                                             arrayLength:sizeof(trustStoreArray)/sizeof(trustStoreArray[0])];
    
    // Create a configuration
    NSDictionary *trustKitConfig = @{kTSKPinnedDomains :
                                         @{@"www.good.com" : @{
                                                   kTSKPublicKeyAlgorithms : @[kTSKAlgorithmRsa4096],
                                                   kTSKPublicKeyHashes : @[@"iQMk4onrJJz/nwW1wCUR0Ycsh3omhbM+PqMEwNof/K0=", // CA Key
                                                                           @"iQMk4onrJJz/nwW1wCUR0Ycsh3omhbM+PqMEwNof/K0=" // CA Key
                                                                           ]}}};
    
    // First test the verifyPublicKeyPin() function
    NSDictionary *parsedTrustKitConfig = parseTrustKitArguments(trustKitConfig);
    
    TSKPinValidationResult verificationResult = TSKPinValidationResultFailed;
    verificationResult = verifyPublicKeyPin(trust,
                                            @"www.good.com",
                                            parsedTrustKitConfig[kTSKPinnedDomains][@"www.good.com"][kTSKPublicKeyAlgorithms],
                                            parsedTrustKitConfig[kTSKPinnedDomains][@"www.good.com"][kTSKPublicKeyHashes]);
    
    
    XCTAssert(verificationResult == TSKPinValidationResultSuccess, @"Validation must pass against valid public key pins");
    
    
    // Then test TSKPinningValidator
    [TrustKit initializeWithConfiguration:trustKitConfig];
    XCTAssert([TSKPinningValidator evaluateTrust:trust forHostname:@"www.good.com"] == TSKTrustDecisionShouldAllowConnection);
    CFRelease(trust);
}


// Pin only to the leaf certificate public key and ensure it succeeds
- (void)testVerifyAgainstLeafPublicKey
{
    // Create a valid server trust
    SecCertificateRef certChainArray[2] = {_leafCertificate, _intermediateCertificate};
    SecCertificateRef trustStoreArray[1] = {_rootCertificate};
    SecTrustRef trust = [TSKCertificateUtils createTrustWithCertificates:(const void **)certChainArray
                                                             arrayLength:sizeof(certChainArray)/sizeof(certChainArray[0])
                                                      anchorCertificates:(const void **)trustStoreArray
                                                             arrayLength:sizeof(trustStoreArray)/sizeof(trustStoreArray[0])];
    
    // Create a configuration
    NSDictionary *trustKitConfig = @{kTSKPinnedDomains :
                                         @{@"www.good.com" : @{
                                                   kTSKPublicKeyAlgorithms : @[kTSKAlgorithmRsa4096],
                                                   kTSKPublicKeyHashes : @[@"TQEtdMbmwFgYUifM4LDF+xgEtd0z69mPGmkp014d6ZY=", // Leaf Key
                                                                           @"TQEtdMbmwFgYUifM4LDF+xgEtd0z69mPGmkp014d6ZY=" // Leaf Key
                                                                           ]}}};
    
    // First test the verifyPublicKeyPin() function
    NSDictionary *parsedTrustKitConfig = parseTrustKitArguments(trustKitConfig);
    
    TSKPinValidationResult verificationResult = TSKPinValidationResultFailed;
    verificationResult = verifyPublicKeyPin(trust,
                                            @"www.good.com",
                                            parsedTrustKitConfig[kTSKPinnedDomains][@"www.good.com"][kTSKPublicKeyAlgorithms],
                                            parsedTrustKitConfig[kTSKPinnedDomains][@"www.good.com"][kTSKPublicKeyHashes]);
    
    
    XCTAssert(verificationResult == TSKPinValidationResultSuccess, @"Validation must pass against valid public key pins");
    
    
    // Then test TSKPinningValidator
    [TrustKit initializeWithConfiguration:trustKitConfig];
    XCTAssert([TSKPinningValidator evaluateTrust:trust forHostname:@"www.good.com"] == TSKTrustDecisionShouldAllowConnection);
    CFRelease(trust);
}


// Pin a bad key and ensure validation fails
- (void)testVerifyAgainstBadPublicKey
{
    // Create a valid server trust
    SecCertificateRef certChainArray[2] = {_leafCertificate, _intermediateCertificate};
    SecCertificateRef trustStoreArray[1] = {_rootCertificate};
    SecTrustRef trust = [TSKCertificateUtils createTrustWithCertificates:(const void **)certChainArray
                                                             arrayLength:sizeof(certChainArray)/sizeof(certChainArray[0])
                                                      anchorCertificates:(const void **)trustStoreArray
                                                             arrayLength:sizeof(trustStoreArray)/sizeof(trustStoreArray[0])];
    
    // Create a configuration
    NSDictionary *trustKitConfig = @{kTSKPinnedDomains :
                                         @{@"www.good.com" : @{
                                                   kTSKPublicKeyAlgorithms : @[kTSKAlgorithmRsa4096],
                                                   kTSKPublicKeyHashes : @[@"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", // Bad Key
                                                                           @"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" // Bad key
                                                                           ]}}};
    
    // First test the verifyPublicKeyPin() function
    NSDictionary *parsedTrustKitConfig = parseTrustKitArguments(trustKitConfig);
    
    TSKPinValidationResult verificationResult = TSKPinValidationResultFailed;
    verificationResult = verifyPublicKeyPin(trust,
                                            @"www.good.com",
                                            parsedTrustKitConfig[kTSKPinnedDomains][@"www.good.com"][kTSKPublicKeyAlgorithms],
                                            parsedTrustKitConfig[kTSKPinnedDomains][@"www.good.com"][kTSKPublicKeyHashes]);
    
    
    XCTAssert(verificationResult == TSKPinValidationResultFailed, @"Validation must fail against bad public key pins");
    
    
    // Then test TSKPinningValidator
    [TrustKit initializeWithConfiguration:trustKitConfig];
    XCTAssert([TSKPinningValidator evaluateTrust:trust forHostname:@"www.good.com"] == TSKTrustDecisionShouldBlockConnection);
    CFRelease(trust);
}


// Pin a bad key but do not enforce pinning and ensure the connection is allowed
- (void)testVerifyAgainstBadPublicKeyPinningNotEnforced
{
    // Create a valid server trust
    SecCertificateRef certChainArray[2] = {_leafCertificate, _intermediateCertificate};
    SecCertificateRef trustStoreArray[1] = {_rootCertificate};
    SecTrustRef trust = [TSKCertificateUtils createTrustWithCertificates:(const void **)certChainArray
                                                             arrayLength:sizeof(certChainArray)/sizeof(certChainArray[0])
                                                      anchorCertificates:(const void **)trustStoreArray
                                                             arrayLength:sizeof(trustStoreArray)/sizeof(trustStoreArray[0])];
    
    // Create a configuration
    NSDictionary *trustKitConfig = @{kTSKPinnedDomains :
                                         @{@"www.good.com" : @{
                                                   kTSKEnforcePinning: @NO,
                                                   kTSKPublicKeyAlgorithms : @[kTSKAlgorithmRsa4096],
                                                   kTSKPublicKeyHashes : @[@"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", // Bad Key
                                                                           @"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" // Bad key
                                                                           ]}}};
    
    // First test the verifyPublicKeyPin() function
    NSDictionary *parsedTrustKitConfig = parseTrustKitArguments(trustKitConfig);
    
    TSKPinValidationResult verificationResult = TSKPinValidationResultFailed;
    verificationResult = verifyPublicKeyPin(trust,
                                            @"www.good.com",
                                            parsedTrustKitConfig[kTSKPinnedDomains][@"www.good.com"][kTSKPublicKeyAlgorithms],
                                            parsedTrustKitConfig[kTSKPinnedDomains][@"www.good.com"][kTSKPublicKeyHashes]);
    
    
    XCTAssert(verificationResult == TSKPinValidationResultFailed, @"Validation must fail against bad public key pins");
    
    
    // Then test TSKPinningValidator
    [TrustKit initializeWithConfiguration:trustKitConfig];
    XCTAssert([TSKPinningValidator evaluateTrust:trust forHostname:@"www.good.com"] == TSKTrustDecisionShouldAllowConnection);
    CFRelease(trust);
}



// Pin a bad key and a good key and ensure validation succeeds
- (void)testVerifyAgainstLeafPublicKeyAndBadPublicKey
{
    // Create a valid server trust
    SecCertificateRef certChainArray[2] = {_leafCertificate, _intermediateCertificate};
    SecCertificateRef trustStoreArray[1] = {_rootCertificate};
    SecTrustRef trust = [TSKCertificateUtils createTrustWithCertificates:(const void **)certChainArray
                                                             arrayLength:sizeof(certChainArray)/sizeof(certChainArray[0])
                                                      anchorCertificates:(const void **)trustStoreArray
                                                             arrayLength:sizeof(trustStoreArray)/sizeof(trustStoreArray[0])];
    
    // Create a configuration
    NSDictionary *trustKitConfig = @{kTSKPinnedDomains :
                                         @{@"www.good.com" : @{
                                                   kTSKPublicKeyAlgorithms : @[kTSKAlgorithmRsa4096],
                                                   kTSKPublicKeyHashes : @[@"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", // Bad key
                                                                           @"TQEtdMbmwFgYUifM4LDF+xgEtd0z69mPGmkp014d6ZY="  // Leaf key
                                                                           ]}}};
    
    // First test the verifyPublicKeyPin() function
    NSDictionary *parsedTrustKitConfig = parseTrustKitArguments(trustKitConfig);
    
    TSKPinValidationResult verificationResult = TSKPinValidationResultFailed;
    verificationResult = verifyPublicKeyPin(trust,
                                            @"www.good.com",
                                            parsedTrustKitConfig[kTSKPinnedDomains][@"www.good.com"][kTSKPublicKeyAlgorithms],
                                            parsedTrustKitConfig[kTSKPinnedDomains][@"www.good.com"][kTSKPublicKeyHashes]);
    
    
    XCTAssert(verificationResult == TSKPinValidationResultSuccess, @"Validation must pass against valid public key pins");
    
    
    // Then test TSKPinningValidator
    [TrustKit initializeWithConfiguration:trustKitConfig];
    XCTAssert([TSKPinningValidator evaluateTrust:trust forHostname:@"www.good.com"] == TSKTrustDecisionShouldAllowConnection);
    CFRelease(trust);
}


// Pin the valid CA key with an invalid certificate chain and ensure validation fails
- (void)testVerifyAgainstCaPublicKeyAndBadCertificateChain
{
    // The leaf certificate is self-signed
    SecCertificateRef certChainArray[2] = {_selfSignedCertificate, _intermediateCertificate};
    SecCertificateRef trustStoreArray[1] = {_rootCertificate};
    SecTrustRef trust = [TSKCertificateUtils createTrustWithCertificates:(const void **)certChainArray
                                                             arrayLength:sizeof(certChainArray)/sizeof(certChainArray[0])
                                                      anchorCertificates:(const void **)trustStoreArray
                                                             arrayLength:sizeof(trustStoreArray)/sizeof(trustStoreArray[0])];
    
    // Create a configuration
    NSDictionary *trustKitConfig = @{kTSKPinnedDomains :
                                         @{@"www.good.com" : @{
                                                   kTSKPublicKeyAlgorithms : @[kTSKAlgorithmRsa4096],
                                                   kTSKPublicKeyHashes : @[@"iQMk4onrJJz/nwW1wCUR0Ycsh3omhbM+PqMEwNof/K0=", // CA key
                                                                           @"iQMk4onrJJz/nwW1wCUR0Ycsh3omhbM+PqMEwNof/K0=" // CA key
                                                                           ]}}};
    
    // First test the verifyPublicKeyPin() function
    NSDictionary *parsedTrustKitConfig = parseTrustKitArguments(trustKitConfig);
    
    TSKPinValidationResult verificationResult = TSKPinValidationResultFailed;
    verificationResult = verifyPublicKeyPin(trust,
                                            @"www.good.com",
                                            parsedTrustKitConfig[kTSKPinnedDomains][@"www.good.com"][kTSKPublicKeyAlgorithms],
                                            parsedTrustKitConfig[kTSKPinnedDomains][@"www.good.com"][kTSKPublicKeyHashes]);
    
    
    XCTAssert(verificationResult == TSKPinValidationResultFailedCertificateChainNotTrusted, @"Validation must fail against bad certificate chain");
    
    
    // Then test TSKPinningValidator
    [TrustKit initializeWithConfiguration:trustKitConfig];
    XCTAssert([TSKPinningValidator evaluateTrust:trust forHostname:@"www.good.com"] == TSKTrustDecisionShouldBlockConnection);
    CFRelease(trust);
}


// Pin the valid CA key with an valid certificate chain but a wrong hostname and ensure validation fails
- (void)testVerifyAgainstCaPublicKeyAndBadHostname
{
    // The certificate chain is valid for www.good.com but we are connecting to www.bad.com
    SecCertificateRef certChainArray[2] = {_leafCertificate, _intermediateCertificate};
    SecCertificateRef trustStoreArray[1] = {_rootCertificate};
    SecTrustRef trust = [TSKCertificateUtils createTrustWithCertificates:(const void **)certChainArray
                                                             arrayLength:sizeof(certChainArray)/sizeof(certChainArray[0])
                                                      anchorCertificates:(const void **)trustStoreArray
                                                             arrayLength:sizeof(trustStoreArray)/sizeof(trustStoreArray[0])];
    
    
    // Create a configuration
    NSDictionary *trustKitConfig = @{kTSKPinnedDomains :
                                         @{@"www.bad.com" : @{
                                                   kTSKPublicKeyAlgorithms : @[kTSKAlgorithmRsa4096],
                                                   kTSKPublicKeyHashes : @[@"iQMk4onrJJz/nwW1wCUR0Ycsh3omhbM+PqMEwNof/K0=", // CA Key
                                                                           @"iQMk4onrJJz/nwW1wCUR0Ycsh3omhbM+PqMEwNof/K0=" // CA Key
                                                                           ]}}};
    
    // First test the verifyPublicKeyPin() function
    NSDictionary *parsedTrustKitConfig = parseTrustKitArguments(trustKitConfig);
    
    TSKPinValidationResult verificationResult = TSKPinValidationResultFailed;
    verificationResult = verifyPublicKeyPin(trust,
                                            @"www.bad.com",
                                            parsedTrustKitConfig[kTSKPinnedDomains][@"www.bad.com"][kTSKPublicKeyAlgorithms],
                                            parsedTrustKitConfig[kTSKPinnedDomains][@"www.bad.com"][kTSKPublicKeyHashes]);
    
    
    XCTAssert(verificationResult == TSKPinValidationResultFailedCertificateChainNotTrusted, @"Validation must fail against bad hostname");
    
    
    // Then test TSKPinningValidator
    [TrustKit initializeWithConfiguration:trustKitConfig];
    XCTAssert([TSKPinningValidator evaluateTrust:trust forHostname:@"www.bad.com"] == TSKTrustDecisionShouldBlockConnection);
    CFRelease(trust);
}


- (void)testDomainNotPinned
{
    // The certificate chain is valid for www.good.com but we are connecting to www.bad.com
    SecCertificateRef certChainArray[2] = {_leafCertificate, _intermediateCertificate};
    SecCertificateRef trustStoreArray[1] = {_rootCertificate};
    SecTrustRef trust = [TSKCertificateUtils createTrustWithCertificates:(const void **)certChainArray
                                                             arrayLength:sizeof(certChainArray)/sizeof(certChainArray[0])
                                                      anchorCertificates:(const void **)trustStoreArray
                                                             arrayLength:sizeof(trustStoreArray)/sizeof(trustStoreArray[0])];
    
    
    // Create a configuration
    NSDictionary *trustKitConfig = @{kTSKPinnedDomains :
                                         @{@"www.good.com" : @{
                                                   kTSKPublicKeyAlgorithms : @[kTSKAlgorithmRsa4096],
                                                   kTSKPublicKeyHashes : @[@"iQMk4onrJJz/nwW1wCUR0Ycsh3omhbM+PqMEwNof/K0=", // CA Key
                                                                           @"iQMk4onrJJz/nwW1wCUR0Ycsh3omhbM+PqMEwNof/K0=" // CA Key
                                                                           ]}}};
  
    // Then test TSKPinningValidator
    [TrustKit initializeWithConfiguration:trustKitConfig];
    XCTAssert([TSKPinningValidator evaluateTrust:trust forHostname:@"www.bad.com"] == TSKTrustDecisionDomainNotPinned);
    CFRelease(trust);
}



@end
