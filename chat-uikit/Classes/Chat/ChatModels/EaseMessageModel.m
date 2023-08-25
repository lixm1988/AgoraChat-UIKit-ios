//
//  EaseMessageModel.m
//  EaseChat
//
//  Created by XieYajie on 2019/1/18.
//  Copyright © 2019 XieYajie. All rights reserved.
//

#import "EaseMessageModel.h"
#import "EaseHeaders.h"
#import "EaseMessageCell.h"
#import "EaseMessageCell+Category.h"
#import <AgoraChat/NSObject+Coding.h>
#import "EaseUserUtils.h"
#import "EaseWebImageManager.h"
#import "EaseEmojiHelper.h"

@interface EaseMessageModel ()


@property (nonatomic, assign, readwrite) CGFloat quoteHeight;
@end

@implementation EaseMessageModel

- (instancetype)initWithAgoraChatMessage:(AgoraChatMessage *)aMsg
{
    self = [super init];
    if (self) {
        self.isUrl = NO;
        _selected = NO;
        _quoteHeight = 0;
        self.message = aMsg;
        _direction = aMsg.direction;
        _type = (AgoraChatMessageType)aMsg.body.type;
        if (aMsg.body.type == AgoraChatMessageBodyTypeText) {
            if ([aMsg.ext objectForKey:MSG_EXT_GIF]) {
                _type = AgoraChatMessageTypeExtGif;
                return self;
            }
            if ([aMsg.ext objectForKey:MSG_EXT_RECALL]) {
                _type = AgoraChatMessageTypeExtRecall;
                return self;
            }
            if ([[aMsg.ext objectForKey:MSG_EXT_NEWNOTI] isEqualToString:NOTI_EXT_ADDFRIEND]) {
                _type = AgoraChatMessageTypeExtNewFriend;
                return self;
            }
            if ([[aMsg.ext objectForKey:MSG_EXT_NEWNOTI] isEqualToString:NOTI_EXT_ADDGROUP]) {
                _type = AgoraChatMessageTypeExtAddGroup;
                return self;
            }
            
            NSString *conferenceId = [aMsg.ext objectForKey:@"conferenceId"];
            if ([conferenceId length] == 0)
                conferenceId = [aMsg.ext objectForKey:MSG_EXT_CALLID];
            if ([conferenceId length] > 0) {
                _type = AgoraChatMessageTypeExtCall;
                return self;
            }
            NSString *text = ((AgoraChatTextMessageBody *)aMsg.body).text;
            self.isUrl = [self detectURL:text];
            NSDictionary *quoteInfo = aMsg.ext[@"msgQuote"];
            if (![quoteInfo isKindOfClass:[NSDictionary class]]) {
                return self;
            }
            if (quoteInfo) {
                NSDictionary <NSString *, NSNumber *>*msgTypeDict = @{
                    @"txt": @(AgoraChatMessageBodyTypeText),
                    @"img": @(AgoraChatMessageBodyTypeImage),
                    @"video": @(AgoraChatMessageBodyTypeVideo),
                    @"audio": @(AgoraChatMessageBodyTypeVoice),
                    @"custom": @(AgoraChatMessageBodyTypeCustom),
                    @"file": @(AgoraChatMessageBodyTypeFile),
                    @"location": @(AgoraChatMessageBodyTypeLocation),@"Chat History": @(AgoraChatMessageBodyTypeCombine)
                };
                NSString *quoteMsgId = quoteInfo[@"msgID"];
                AgoraChatMessageBodyType msgBodyType = msgTypeDict[quoteInfo[@"msgType"]].intValue;
                NSString *msgSender = quoteInfo[@"msgSender"];
                NSString *msgPreview = quoteInfo[@"msgPreview"];
                msgPreview = [EaseEmojiHelper convertEmoji:msgPreview];
                AgoraChatMessage *quoteMessage = [AgoraChatClient.sharedClient.chatManager getMessageWithMessageId:quoteMsgId];                id<EaseUserProfile> userInfo = [EaseUserUtils.shared getUserInfo:msgSender moduleType:quoteMessage.chatType == AgoraChatTypeChat ? EaseUserModuleTypeChat : EaseUserModuleTypeGroupChat];
                NSString *showName = userInfo.showName.length > 0 ? userInfo.showName : msgSender;
                NSMutableAttributedString *result = [[NSMutableAttributedString alloc] init];
                NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
                paragraphStyle.lineHeightMultiple = 1.07;
                [result appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@:", showName] attributes:@{NSForegroundColorAttributeName:[UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1],NSFontAttributeName:[UIFont systemFontOfSize:11 weight:UIFontWeightSemibold],NSParagraphStyleAttributeName:paragraphStyle}]];
                if (quoteMessage.chatThread) {
                    self.quoteContent = [self appendImage:result imageQuote:NO image:[UIImage easeUIImageNamed:@"groupThread"]];
                    if (!IsStringEmpty(quoteMessage.chatThread.threadName)) {
                        self.quoteContent = [self appendContent:quoteMessage.chatThread.threadName];
                    }
                    
                } else {
                    __weak typeof(self) weakSelf = self;
                    switch (msgBodyType) {
                        case AgoraChatMessageBodyTypeText:
                        {
                            self.quoteContent = result;
                            if ([self detectURL:msgPreview]) {
                                self.quoteContent = [self appendImage:result imageQuote:NO image:[UIImage easeUIImageNamed:@"quote_link"]];
                            }
                            self.quoteContent = [self appendContent:msgPreview];
                        }
                            break;
                        case AgoraChatMessageBodyTypeImage:
                        {
                            __block UIImage *img = [UIImage easeUIImageNamed:@"msg_img_broken"];
                            if ([((AgoraChatImageMessageBody *)quoteMessage.body).localPath length] > 0) {
                                img = [UIImage imageWithContentsOfFile:((AgoraChatImageMessageBody *)quoteMessage.body).localPath];
                            }
                            if (!img) {
                                if (((AgoraChatImageMessageBody *)quoteMessage.body).thumbnailRemotePath.length) {
                                    NSURL *imageURL = [NSURL URLWithString:((AgoraChatImageMessageBody *)quoteMessage.body).thumbnailRemotePath];
                                    [EaseWebImageManager.sharedManager loadImageWithURL:imageURL options:nil progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, EaseImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                                        if (error == nil && image != nil) {
                                            img = image;
                                        } else {
                                            img = [UIImage easeUIImageNamed:@"msg_img_broken"];
                                        }
                                        weakSelf.quoteContent = [weakSelf appendImage:result imageQuote:YES image:img];
                                        weakSelf.quoteHeight;
                                    }];
                                } else {
                                    img = [UIImage easeUIImageNamed:@"msg_img_broken"];
                                    self.quoteContent = [self appendImage:result imageQuote:true image:img];
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        self.quoteHeight;
                                    });
                                }
                                
                            } else {
                                self.quoteContent = [self appendImage:result imageQuote:YES image:img];
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    self.quoteHeight;
                                });
                            }
                        }
                            break;
                        case AgoraChatMessageBodyTypeVideo:
                        {
                            __block UIImage *img = [[UIImage easeUIImageNamed:@"msg_img_broken"] Ease_resizedImageWithSize:CGSizeMake(80, 80) scaleMode:EaseImageScaleModeAspectFill];;
                            if ([((AgoraChatVideoMessageBody *)quoteMessage.body).thumbnailLocalPath length] > 0) {
                                img = [[UIImage imageWithContentsOfFile:((AgoraChatVideoMessageBody *)quoteMessage.body).thumbnailLocalPath] Ease_resizedImageWithSize:CGSizeMake(80, 80) scaleMode:EaseImageScaleModeAspectFill];
                            }
                            if (!img) {
                                if (((AgoraChatImageMessageBody *)quoteMessage.body).thumbnailRemotePath.length) {
                                    NSURL *imageURL = [NSURL URLWithString:((AgoraChatVideoMessageBody *)quoteMessage.body).thumbnailRemotePath];
                                    [EaseWebImageManager.sharedManager loadImageWithURL:imageURL options:nil progress:nil completed:^(UIImage * _Nullable image, NSData * _Nullable data, NSError * _Nullable error, EaseImageCacheType cacheType, BOOL finished, NSURL * _Nullable imageURL) {
                                        if (error == nil && image != nil) {
                                            img = [image Ease_resizedImageWithSize:CGSizeMake(80, 80) scaleMode:EaseImageScaleModeAspectFill];
                                        } else {
                                            img = [[UIImage easeUIImageNamed:@"msg_img_broken"] Ease_resizedImageWithSize:CGSizeMake(80, 80) scaleMode:EaseImageScaleModeAspectFill];
                                        }
                                        weakSelf.quoteContent = [weakSelf appendImage:result imageQuote:YES image:[weakSelf combineImage:img coverImage:[UIImage easeUIImageNamed:@"video_cover"]]];
                                        weakSelf.quoteHeight;
                                    }];
                                }  else {
                                    img = [[UIImage easeUIImageNamed:@"msg_img_broken"] Ease_resizedImageWithSize:CGSizeMake(80, 80) scaleMode:EaseImageScaleModeAspectFill];;
                                    self.quoteContent = [self appendImage:result imageQuote:YES image:[self combineImage:img coverImage:[UIImage easeUIImageNamed:@"video_cover"]]];
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        self.quoteHeight;
                                    });
                                }
                            } else {
                                self.quoteContent = [self appendImage:result imageQuote:YES image:[self combineImage:img coverImage:[UIImage easeUIImageNamed:@"video_cover"]]];
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    self.quoteHeight;
                                });
                            }
                            
                        }
                            break;
                        case AgoraChatMessageBodyTypeVoice:
                        {
                            self.quoteContent = [self appendImage:result imageQuote:NO image:[UIImage easeUIImageNamed:@"quote_voice"]];
                            if (((AgoraChatVoiceMessageBody *)quoteMessage.body).duration > 0) {
                                self.quoteContent = [self appendContent:[NSString stringWithFormat:@"%d”", ((AgoraChatVoiceMessageBody *)quoteMessage.body).duration]];
                            }
                            
                        }
                            break;
                        case AgoraChatMessageBodyTypeFile:
                        {
                            self.quoteContent = [self appendImage:result imageQuote:NO image:[UIImage easeUIImageNamed:@"quote_file"]];
                            if (((AgoraChatFileMessageBody *)quoteMessage.body).displayName.length) {
                                self.quoteContent = [self appendContent:((AgoraChatFileMessageBody *)quoteMessage.body).displayName];
                            }
                        }
                            break;
                        case AgoraChatMessageBodyTypeCombine:
                        {
                            self.quoteContent = [self appendImage:result imageQuote:NO image:[UIImage easeUIImageNamed:@"quote_combine"]];
                            if (((AgoraChatCombineMessageBody *)quoteMessage.body).title.length) {
                                self.quoteContent = [self appendContent:((AgoraChatCombineMessageBody *)quoteMessage.body).title];
                            }
                        }
                            break;
                            
                        default:
                            break;
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.quoteHeight;
                    });
                }
            }

        }
    }

    return self;
}

- (BOOL)detectURL:(NSString *)string {
    NSError *error;
    NSDataDetector *detector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error];
    NSArray *matches = [detector matchesInString:string options:0 range:NSMakeRange(0, [string length])];
    if (matches.count > 0) {
        return YES;
    }
    return NO;
}


- (void)setMessage:(AgoraChatMessage *)message {
    _message = message;
}

- (id)copyWithZone:(NSZone *)zone {
    return [self ease_copyWithZone:zone];
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    return [self ease_mutableCopyWithZone:zone];
}

- (CGFloat)quoteHeight {
    UILabel *label = [UILabel new];
    label.numberOfLines = 0;
    label.attributedText = self.quoteContent;
    _quoteHeight = ceilf([label sizeThatFits:CGSizeMake(EMScreenWidth*0.75-24, 999)].height+16);
    label = nil;
    return _quoteHeight;
}

- (NSAttributedString *)appendImage:(NSMutableAttributedString *_Nonnull)attributeText imageQuote:(BOOL)imageQuote image:(UIImage *)image {
    NSTextAttachment *attachment = [[NSTextAttachment alloc] init];
    attachment.image = image;
    CGSize size = imageQuote ? ImageQuoteSize:CompositeStyleSize;
    attachment.bounds = CGRectMake(0, -size.height/4, size.width, size.height);
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.alignment = NSTextAlignmentLeft;
    paragraphStyle.headIndent = 4; // 调整图片与文字的间距
    NSAttributedString *imageAttribute = [NSAttributedString attributedStringWithAttachment:attachment];
    [attributeText addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, attributeText.length)];
    [attributeText appendAttributedString:imageAttribute];
    return attributeText;
}

- (NSAttributedString *)appendContent:(NSString *_Nonnull)content {
    NSMutableAttributedString *show = [[NSMutableAttributedString alloc] initWithAttributedString:self.quoteContent];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineHeightMultiple = 1.12;
    NSAttributedString *text = [[NSAttributedString alloc] initWithString:content attributes:@{NSForegroundColorAttributeName:[UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1],NSFontAttributeName:[UIFont systemFontOfSize:12 weight:UIFontWeightRegular],NSParagraphStyleAttributeName:paragraphStyle}];
    [show appendAttributedString:text];
    return show;
}

- (UIImage *)combineImage:(UIImage *)image coverImage:(UIImage *)coverImage {
    UIGraphicsBeginImageContextWithOptions(image.size, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    [coverImage drawInRect:CGRectMake(image.size.width/2.0-coverImage.size.width/2.0, image.size.height/2.0-coverImage.size.height/2.0, coverImage.size.width, coverImage.size.height)];
    UIImage *resultingImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resultingImage;
}

@end
