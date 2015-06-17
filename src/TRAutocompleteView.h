//
// Copyright (c) 2013, Taras Roshko
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// The views and conclusions contained in the software and documentation are those
// of the authors and should not be interpreted as representing official policies,
// either expressed or implied, of the FreeBSD Project.
//

#import <Foundation/Foundation.h>
#import "SuggestionsList.h"
#import "TRAutocompleteItemsSource.h"

typedef enum SuggestionMode : NSUInteger {
    Normal,
    Popover
} SuggestionMode;

@protocol TRAutocompleteItemsSource;
@protocol TRAutocompletionCellFactory;
@protocol TRSuggestionItem;


@interface TRAutocompleteView : UIView

@property(readonly) id <TRSuggestionItem> selectedSuggestion;
@property(nonatomic, strong) NSMutableArray *suggestions;

@property(copy) didAutocompletionBlock autocompletionBlock;

@property(nonatomic) UIColor *separatorColor;
@property(nonatomic) UITableViewCellSeparatorStyle separatorStyle;

@property(nonatomic) CGFloat topMargin;

@property(readonly) SuggestionMode suggestionMode;

@property(nonatomic, assign) BOOL isLaunchedWithScanner;


+ (TRAutocompleteView *)autocompleteViewBindedTo:(UITextField *)textField
                                     usingSource:(id <TRAutocompleteItemsSource>)itemsSource
                                     cellFactory:(id <TRAutocompletionCellFactory>)factory
                                    presentingIn:(UIViewController *)controller withMode:(SuggestionMode)mode
                               whenSelectionMade:(didAutocompletionBlock)autocompleteBlock;

- (void)queryChanged:(id)sender;
- (void)queryChangedWithSuccessBlock:(void (^)(NSArray *suggestions))successBlock;
- (void)refreshTableViewWithSuggestions:(NSArray *)suggestions;
-(BOOL)selectSingleMatch;

@end