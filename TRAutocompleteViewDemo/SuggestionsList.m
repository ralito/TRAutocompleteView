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
@synthesize  matchedStrings = _matchedStrings;
@synthesize popOver = _popOver;
@synthesize activeTextField = _activeTextField;
@synthesize itemSource = _itemSource;

-(id)initWithAutocompleteItemSource:(id<TRAutocompleteItemsSource>)itemSource
{
    self = [super init];
    if (self) {
        
        self.suggestionsArray = [NSArray array];
        self.matchedStrings = [NSArray array];
        self.itemSource=itemSource;
        
        //Initializing PopOver
        self.popOver = [[UIPopoverController alloc] initWithContentViewController:self];
        self.popOver.popoverContentSize = CGSizeMake(POPOVER_WIDTH, POPOVER_HEIGHT);
    }
    return self;
}
#pragma mark Main Suggestions Methods
-(void)matchString:(NSString *)letters {
    self.matchedStrings = nil;
    
    if (_suggestionsArray == nil) {
        @throw [NSException exceptionWithName:@"Please set an array to suggestionsArray" reason:@"No array specified" userInfo:nil];
    }
    
    self.matchedStrings = [_suggestionsArray filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        return [[evaluatedObject completionText] hasPrefix:letters];
    }]];
                           
    [self.tableView reloadData];
}

-(void)showPopOverListFor:(UITextField*)textField{
    UIPopoverArrowDirection arrowDirection = UIPopoverArrowDirectionUp;
    if ([self.matchedStrings count] == 0) {
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
    return [self.matchedStrings count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    cell.textLabel.text = [self.matchedStrings objectAtIndex:indexPath.row];
    
    return cell;
}
#pragma mark - Table view delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.activeTextField setText:[self.matchedStrings objectAtIndex:indexPath.row]];
    [self.popOver dismissPopoverAnimated:YES];
    
    id suggestion = self.suggestionsArray[(NSUInteger) indexPath.row];
    NSAssert([suggestion conformsToProtocol:@protocol(TRSuggestionItem)], @"Suggestion item must conform TRSuggestionItem");
    
    _itemSource.selectedSuggestion = (id <TRSuggestionItem>) suggestion;
    
    _activeTextField.text = [suggestion completionText];
    [_activeTextField resignFirstResponder];
    
    if (self.didAutocompleteWith)
        self.didAutocompleteWith(suggestion);
    
    
}
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}

@end
