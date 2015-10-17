//
//  SuggestionMenu.h
//  AutoComplete
//
//  Created by Wojciech Mandrysz on 19/09/2011.
//  Copyright 2011 http://tetek.me . All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TRAutocompleteItemsSource.h"
#import <FPPopover/FPPopoverController.h>

@interface SuggestionsList : UITableViewController 

-(id)initWithAutocompleteItemSource:(id<TRAutocompleteItemsSource>)itemSource andAutocompletionBlock:(didAutocompletionBlock)autocompletionBlock withCellFont:(UIFont*)cellFont;
-(void)showSuggestionsFor:(UITextField*)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString*)string;
-(void)showSuggestionsFor:(UITextField*)textField;

@property(retain)NSArray *suggestionsArray;
@property(retain)NSArray *matchedSuggestions;
@property(retain) FPPopoverController *popOver;
@property(retain) UIFont *cellFont;
@property(retain)id<TRAutocompleteItemsSource> itemSource;
@property(assign)UITextField *activeTextField;


@property(copy) didAutocompletionBlock autocompletionBlock;

@end
