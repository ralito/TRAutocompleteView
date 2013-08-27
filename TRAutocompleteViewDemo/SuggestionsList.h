//
//  SuggestionMenu.h
//  AutoComplete
//
//  Created by Wojciech Mandrysz on 19/09/2011.
//  Copyright 2011 http://tetek.me . All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TRAutocompleteItemsSource.h"

@interface SuggestionsList : UITableViewController 

-(id)initWithAutocompleteItemSource:(id<TRAutocompleteItemsSource>)itemSource;
-(void)showSuggestionsFor:(UITextField*)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString*)string;
-(void)showSuggestionsFor:(UITextField*)textField;

@property(retain)NSArray *suggestionsArray;
@property(retain)NSArray *matchedStrings;
@property(retain)UIPopoverController *popOver;
@property(retain)id<TRAutocompleteItemsSource> itemSource;
@property(copy) didAutocompletionBlock autocompletionBlock;
@property(assign)UITextField *activeTextField;

@end
