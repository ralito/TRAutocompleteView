//
//  SuggestionMenu.m
//  AutoComplete
//
//  Created by Wojciech Mandrysz on 19/09/2011.
//  Copyright 2011 http://tetek.me . All rights reserved.
//

#import "SuggestionsList.h"
#import "TRAutocompleteItemsSource.h"

#define POPOVER_WIDTH 250
#define POPOVER_HEIGHT 260

@implementation SuggestionsList

@synthesize suggestionsArray = _suggestionsArray;
@synthesize  matchedSuggestions = _matchedSuggestions;
@synthesize popOver = _popOver;
@synthesize activeTextField = _activeTextField;
@synthesize itemSource = _itemSource;
@synthesize autocompletionBlock;

-(id)initWithAutocompleteItemSource:(id<TRAutocompleteItemsSource>)itemSource andAutocompletionBlock:(didAutocompletionBlock)autocompletionBlock_
{
    self = [super init];
    if (self) {
        
        self.suggestionsArray = [NSArray array];
        self.matchedSuggestions = [NSArray array];
        self.itemSource=itemSource;
        
        //Initializing PopOver
        self.popOver = [[UIPopoverController alloc] initWithContentViewController:self];
        self.popOver.popoverContentSize = CGSizeMake(POPOVER_WIDTH, POPOVER_HEIGHT);
        self.autocompletionBlock=autocompletionBlock_;
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
        return [[evaluatedObject completionText] hasPrefix:letters];
    }]];
                           
    [self.tableView reloadData];
}

-(void)showPopOverListFor:(UITextField*)textField{
    UIPopoverArrowDirection arrowDirection = UIPopoverArrowDirectionUp;
    if ([self.matchedSuggestions count] == 0) {
        [_popOver dismissPopoverAnimated:YES];
    }
    else if(!_popOver.isPopoverVisible){
        [_popOver presentPopoverFromRect:textField.frame inView:textField.superview permittedArrowDirections:arrowDirection animated:YES];
        
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

@end
