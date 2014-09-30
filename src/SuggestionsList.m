//
//  SuggestionMenu.m
//  AutoComplete
//
//  Created by Wojciech Mandrysz on 19/09/2011.
//  Copyright 2011 http://tetek.me . All rights reserved.
//

#import "SuggestionsList.h"
#import "TRAutocompleteItemsSource.h"

#define IPAD_POPOVER_WIDTH 350
#define IPHONE_POPOVER_WIDTH 300
#define POPOVER_HEIGHT 324

@implementation SuggestionsList{
    CGFloat popoverWidth;
}

@synthesize suggestionsArray = _suggestionsArray;
@synthesize  matchedSuggestions = _matchedSuggestions;
@synthesize popOver = _popOver;
@synthesize activeTextField = _activeTextField;
@synthesize itemSource = _itemSource;
@synthesize autocompletionBlock;
@synthesize cellFont;

-(id)initWithAutocompleteItemSource:(id<TRAutocompleteItemsSource>)itemSource andAutocompletionBlock:(didAutocompletionBlock)autocompletionBlock_ withCellFont:(UIFont *)cellFont_
{
    self = [super init];
    if (self) {
        
        self.suggestionsArray = [NSArray array];
        self.matchedSuggestions = [NSArray array];
        self.itemSource=itemSource;
        
        //Initializing PopOver
        popoverWidth = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)?IPAD_POPOVER_WIDTH:IPHONE_POPOVER_WIDTH;
        self.popOver = [[FPPopoverController alloc] initWithViewController:self];
        [self.tableView setFrame:CGRectMake(0, 0, popoverWidth, POPOVER_HEIGHT)];
        self.popOver.contentSize = CGSizeMake(popoverWidth, POPOVER_HEIGHT);
        self.popOver.arrowDirection = FPPopoverArrowDirectionUp;
        self.popOver.border = NO;
        self.popOver.tint = FPPopoverWhiteTint;
        self.autocompletionBlock=autocompletionBlock_;
        self.cellFont=cellFont_;
    }
    return self;
}
#pragma mark Main Suggestions Methods
-(void)matchString:(NSString *)letters {
    self.matchedSuggestions = nil;
    
    if (_suggestionsArray == nil) {
        @throw [NSException exceptionWithName:@"Please set an array to suggestionsArray" reason:@"No array specified" userInfo:nil];
    }
    
    self.matchedSuggestions = [_suggestionsArray filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return ([[evaluatedObject completionText] rangeOfString:letters options:NSCaseInsensitiveSearch].location != NSNotFound);
    }]];
                           
    [self.tableView reloadData];
}

-(void)showPopOverListFor:(UITextField*)textField{
    if ([self.matchedSuggestions count] == 0) {
        [_popOver dismissPopoverAnimated:YES];
    }
    else {
        [_popOver presentPopoverFromView:textField];
        
    }
}
-(void)showSuggestionsFor:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string{
    NSMutableString *rightText;
    
    if (textField.text) {
        rightText = [NSMutableString stringWithString:textField.text];
        [rightText replaceCharactersInRange:range withString:string];
    }
    else {
        rightText = [NSMutableString stringWithString:string];
    }
    
    [self matchString:rightText];
    [self showPopOverListFor:textField];
    self.activeTextField = textField;
}

-(void)showSuggestionsFor:(UITextField *)textField{
    
    NSMutableString *rightText;
    
    if (textField.text) {
        rightText = [NSMutableString stringWithString:textField.text];
        [self matchString:rightText];
        [self showPopOverListFor:textField];
        self.activeTextField = textField;
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.matchedSuggestions count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = cellFont;
    }
    
    id item = [self.matchedSuggestions objectAtIndex:indexPath.row];
    cell.textLabel.text = [item completionText];
    
    return cell;
}
#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    id item = [self.matchedSuggestions objectAtIndex:indexPath.row];
    NSAssert([item conformsToProtocol:@protocol(TRSuggestionItem)], @"Suggestion item must conform TRSuggestionItem");
    
    [self.activeTextField setText:[item completionText]];
    [self.popOver dismissPopoverAnimated:YES];
    
    if (self.autocompletionBlock)
        self.autocompletionBlock(item);
    
    _activeTextField.text = [item completionText];
    [_activeTextField resignFirstResponder];

    
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id item = [self.matchedSuggestions objectAtIndex:indexPath.row];
    NSString* text = [item completionText];
    
    CGSize constraintSize = CGSizeMake(popoverWidth, MAXFLOAT);
    CGSize labelSize = [text sizeWithFont:cellFont constrainedToSize:constraintSize lineBreakMode:UILineBreakModeWordWrap];
    
    CGFloat padding = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)?40:25;
    return labelSize.height + padding;
}

@end
