//
//  TKCryptor.m
//  AdyenClientsideEncryption
//
//  Created by Taras Kalapun on 10/26/14.
//  Copyright (c) 2014 Adyen. All rights reserved.
//

#import "TKCryptor.h"
#import "TKAESCCMCryptor.h"
#import "TKRSACryptor.h"
#import <Security/Security.h>
#import <CommonCrypto/CommonCrypto.h>

@implementation TKCryptor

static NSString* crypt_msg_prefix = @"";
static NSString* crypt_msg_separator = @"$";
static NSUInteger crypt_ivLength = 12;

+ (void)setMsgPrefix:(NSString *)prefix {
    if (!prefix) {
        prefix = @"";
    }
    crypt_msg_prefix = prefix;
}

+ (void)setMsgSeparator:(NSString *)separator {
    if (!separator) {
        separator = @"$";
    }
    crypt_msg_separator = separator;
}

+ (NSString *)encrypt:(NSData *)data publicKeyInHex:(NSString *)keyInHex
{
    // generate a unique AES key and (later) encrypt it with the public RSA key of the merchant
    NSMutableData *key = [NSMutableData dataWithLength:kCCKeySizeAES256];
    SecRandomCopyBytes(NULL, kCCKeySizeAES256, key.mutableBytes);
    
    // generate a nonce
    NSMutableData *iv = [NSMutableData dataWithLength:crypt_ivLength];
    SecRandomCopyBytes(NULL, crypt_ivLength, iv.mutableBytes);
    
    NSData *cipherText = [self aesEncrypt:data withKey:key iv:iv];
    
    if (!cipherText) {
        return nil;
    }
    
    // format of the fully composed message:
    // - a prefix
    // - a separator
    // - RSA encrypted AES key, base64 encoded
    // - a separator
    // - a Payload of iv and cipherText, base64 encoded
    NSMutableData *payload = [NSMutableData data];
    [payload appendData:iv];
    [payload appendData:cipherText];
    
    NSData *encryptedKey = [self rsaEncrypt:key withKeyInHex:keyInHex];
    
    NSString *result = nil;
    
    NSString *prefix = (crypt_msg_prefix.length == 0) ? @"" : [crypt_msg_prefix stringByAppendingString:crypt_msg_separator];
    
    if (encryptedKey) {
        result = [NSString stringWithFormat:@"%@%@%@%@",
                  prefix,
                  [encryptedKey base64EncodedStringWithOptions:0],
                  crypt_msg_separator,
                  [payload base64EncodedStringWithOptions:0]];
    }
    
    return result;
}

#pragma mark - Wrappers
+ (NSData *)aesEncrypt:(NSData *)data withKey:(NSData *)key iv:(NSData *)iv
{
    return [TKAESCCMCryptor encrypt:data withKey:key iv:iv];
}

+ (NSData *)rsaEncrypt:(NSData *)data withKeyInHex:(NSString *)keyInHex {
    return [TKRSACryptor encrypt:data withKeyInHex:keyInHex];
}

#pragma mark - Helpers

+ (NSData *)dataFromHex:(NSString *)hex {
    hex = [hex stringByReplacingOccurrencesOfString:@" " withString:@""];
    if (hex.length & 1) {
        hex = [@"0" stringByAppendingString:hex];
    }
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:hex.length/2];
    unsigned char whole_byte;
    char byte_chars[3] = {'\0','\0','\0'};
    int i;
    for (i=0; i < [hex length]/2; i++) {
        byte_chars[0] = [hex characterAtIndex:i*2];
        byte_chars[1] = [hex characterAtIndex:i*2+1];
        whole_byte = strtol(byte_chars, NULL, 16);
        [data appendBytes:&whole_byte length:1];
    }
    return data;
}


+ (NSData *)sha1FromStringInHex:(NSString *)stringInHex {
    NSMutableData *digest = [NSMutableData dataWithCapacity:CC_SHA1_DIGEST_LENGTH];
    NSData *stringBytes = [stringInHex dataUsingEncoding:NSUTF8StringEncoding];
    if (CC_SHA1(stringBytes.bytes, (CC_LONG)stringBytes.length, digest.mutableBytes)) {
        if (digest.length == 0) {
            // fallback if SHA1 failed
            return stringBytes;
        }
        return digest;
    }
    return nil;
}


@end
