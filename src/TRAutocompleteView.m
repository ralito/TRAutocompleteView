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

#import "TRAutocompleteView.h"
#import "TRAutocompleteItemsSource.h"
#import "TRAutocompletionCellFactory.h"
#import "UIScrollView+InfiniteScroll.h"


#define UIViewAutoresizingFlexibleMargins   \
UIViewAutoresizingFlexibleBottomMargin    | \
UIViewAutoresizingFlexibleLeftMargin      | \
UIViewAutoresizingFlexibleRightMargin     | \
UIViewAutoresizingFlexibleTopMargin

static const NSString* kAutocompleteCellIdentifier = @"TRAutocompleteCell";
static const CGFloat   kAutocompleteCellHeight  = 64.0f;
static const CGFloat   kAutocompleteTableViewInsetBottom = 20.0f;
static const CGFloat   kAutocompleteTopMarginDefault = 0.0f;
static const int       kAutocompleteQuerysetPagesizeDefault = 20;

@interface TRAutocompleteView () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

- (BOOL)isSearchTextField;

@end

@implementation TRAutocompleteView
{
    BOOL _visible;

    __weak UITextField *_queryTextField;
    __weak UIViewController *_contextController;
    NSString *_previousQueryText;

    UITableView *_table;
    id <TRAutocompleteItemsSource> _itemsSource;
    id <TRAutocompletionCellFactory> _cellFactory;
}

@synthesize autocompletionBlock;

+ (TRAutocompleteView *)autocompleteViewBindedTo:(UITextField *)textField
                                     usingSource:(id <TRAutocompleteItemsSource>)itemsSource
                                     cellFactory:(id <TRAutocompletionCellFactory>)factory
                                    presentingIn:(UIViewController *)controller
                               whenSelectionMade:(didAutocompletionBlock)autocompleteBlock
{
    return [[TRAutocompleteView alloc] initWithFrame:CGRectZero
                                           textField:textField
                                         itemsSource:itemsSource
                                         cellFactory:factory
                                          controller:controller
                                   whenSelectionMade:autocompleteBlock
            ];
}

- (id)initWithFrame:(CGRect)frame
          textField:(UITextField *)textField
        itemsSource:(id <TRAutocompleteItemsSource>)itemsSource
        cellFactory:(id <TRAutocompletionCellFactory>)factory
         controller:(UIViewController *)controller whenSelectionMade:(didAutocompletionBlock)autocompleteBlock_
{
    self = [super initWithFrame:frame];

    _queryTextField = textField;
    _queryTextField.delegate = self;

    _itemsSource = itemsSource;
    _cellFactory = factory;
    _contextController = controller;
    autocompletionBlock = autocompleteBlock_;
    self.suggestions = [NSMutableArray new];

    if (self) {
        // Preset appearance and autoresizing setup; set view frame correctly based on current desired size
        [self setupView];

        // Initialize and configure table view, with autolayout constraints
        [self setupTableView];

        // Add the spinner
        self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        self.spinner.hidesWhenStopped = YES;
        self.spinner.frame = CGRectMake((self.frame.size.width/2) - (self.spinner.frame.size.width/2), self.frame.size.height/2 - self.frame.origin.y, self.spinner.frame.size.width, self.spinner.frame.size.height);
        [self.spinner startAnimating];
        [self addSubview:self.spinner];

        // Setup action for callback when new search query returns results
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillBeShown:)
                                                     name:UIKeyboardWillShowNotification
                                                   object:nil];
    }
    
    return self;
}

#pragma mark - View setup

- (void)setupView
{
    self.backgroundColor = [UIColor whiteColor];
    self.separatorColor = [UIColor lightGrayColor];
    self.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.topMargin = kAutocompleteTopMarginDefault;
    self.autoresizingMask = UIViewAutoresizingFlexibleMargins;

    BOOL isIPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);

    CGRect controlFrame;
    if ([self isSearchTextField]) {
        controlFrame = _queryTextField.superview.frame;
    }
    else {
        controlFrame = _queryTextField.frame;
    }

    CGFloat contextViewHeight = _contextController.view.frame.size.height;
    CGFloat contextViewWidth = _contextController.view.frame.size.width;
    CGFloat calculatedY = controlFrame.origin.y + controlFrame.size.height + (isIPad ? 0 : StatusBarHeight());

    self.frame = CGRectMake(controlFrame.origin.x, calculatedY, contextViewWidth, contextViewHeight-calculatedY);
}

- (void)setupTableView
{
    _table = [[UITableView alloc] initWithFrame:self.frame style:UITableViewStylePlain];
    _table.delegate = self;
    _table.dataSource = self;

    // Default to clear separation while we load initial data
    _table.backgroundColor = [UIColor clearColor];
    _table.separatorColor = [UIColor clearColor];
    _table.separatorStyle = UITableViewCellSeparatorStyleNone;

    __weak typeof(self) weakSelf = self;
    // Block executed when user scrolls to bottom of table
    [_table addInfiniteScrollWithHandler:^(id scrollView) {

        // We already have all the results, no need to append, just refresh
        if (weakSelf.suggestions.count < kAutocompleteQuerysetPagesizeDefault) {
            [_table reloadData];

            [self.spinner stopAnimating];

            [_table finishInfiniteScroll];
        }
        else {
            // Initiate new query based on current suggestions.count
            [self queryChangedWithSuccessBlock:^(NSArray *suggestionsReturned) {
                // Need to append page results to new array
                NSMutableArray *indexPaths = [@[] mutableCopy];
                NSInteger index = weakSelf.suggestions.count;

                for (id suggestion in suggestionsReturned) {
                    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index++ inSection:0];
                    [indexPaths addObject:indexPath];
                    [weakSelf.suggestions addObject:suggestion];
                }
                // Index paths to be added and animated onto table
                [_table beginUpdates];
                [_table insertRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationBottom];
                [_table endUpdates];

                [self.spinner stopAnimating];

                // End loading animation
                [_table finishInfiniteScroll];
            }];
        }
    }];

    // Disable autoresizing in favor of autolayout with calculated row height
    _table.translatesAutoresizingMaskIntoConstraints = NO;
    _table.estimatedRowHeight = kAutocompleteCellHeight;
    _table.rowHeight = UITableViewAutomaticDimension;

    // Add _table to autocompleteView to configure constraints
    NSDictionary *views = NSDictionaryOfVariableBindings(_table);

    [self addSubview:_table];
    [self addConstraints:[NSLayoutConstraint
                          constraintsWithVisualFormat:@"H:|[_table]|"
                          options:0
                          metrics:nil
                          views:views]];
    [self addConstraints:[NSLayoutConstraint
                          constraintsWithVisualFormat:@"V:|[_table]|"
                          options:0
                          metrics:nil
                          views:views]];
}

#pragma mark - Actions

- (void)showAutocompleteView
{
    if (!_visible) {
        [_contextController.view addSubview:self];
        _visible = YES;
    }
}

- (void)queryChangedWithTextField
{
    // if textField is currently editing, we always want 0th start index of paged results
    NSNumber *startIndex = (_queryTextField.isEditing ? @(0) : @(self.suggestions.count));
    BOOL shouldTriggerSearch = [_queryTextField.text length] >= _itemsSource.minimumCharactersToTrigger;

    if (shouldTriggerSearch) {
        // Automatically fetch latest results and reset suggestions list
        [_itemsSource itemsFor:_queryTextField.text withStartIndex:startIndex whenReady:
         ^(NSArray *suggestions) {
             [self refreshTableViewWithSuggestions:suggestions];
         }];
    }
    else {
        [self refreshTableViewWithSuggestions:nil];
    }
}

- (void)queryChangedWithSuccessBlock:(void (^)(NSArray *suggestions))successBlock
{
    NSNumber *startIndex = (self.isLaunchedWithScanner ? @(0) : @(self.suggestions.count));
    BOOL shouldTriggerSearch = [_queryTextField.text length] >= _itemsSource.minimumCharactersToTrigger;

    if (shouldTriggerSearch) {
        [_itemsSource itemsFor:_queryTextField.text withStartIndex:startIndex whenReady:
         ^(NSArray *suggestions)
         {
             // Scanner code matched == 1 - Select match!
             if (self.suggestions.count == 1) {                    
                  successBlock(suggestions);
             }
             else {
                 if (self.isLaunchedWithScanner) {
                     [self refreshTableViewWithSuggestions:suggestions];
                 }

                 // show suggestions table view
                 if (self.suggestions.count > 0 && !_visible) {
                     [_contextController.view addSubview:self];
                     _visible = YES;
                 }
                 successBlock(suggestions);
             }
         }];
    }
    else {
        [self refreshTableViewWithSuggestions:nil];
    }
}

- (void)refreshTableViewWithSuggestions:(NSArray *)suggestions
{
    _table.separatorColor = self.separatorColor;
    _table.separatorStyle = self.separatorStyle;

    if (suggestions)
        self.suggestions = [suggestions mutableCopy];
    else
        self.suggestions = nil;

    [self.spinner stopAnimating];
    [_table reloadData];
}

#pragma mark - Keyboard notification methods

- (void)keyboardWillBeShown:(NSNotification *)notification
{
    if (!_visible) {
        [_contextController.view addSubview:self];
        _visible = YES;
    }
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.suggestions.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    id cell = [tableView dequeueReusableCellWithIdentifier:kAutocompleteCellIdentifier];
    if (cell == nil)
        cell = [_cellFactory createReusableCellWithIdentifier:kAutocompleteCellIdentifier];
    
    NSAssert([cell isKindOfClass:[UITableViewCell class]], @"Cell must inherit from UITableViewCell");
    NSAssert([cell conformsToProtocol:@protocol(TRAutocompletionCell)], @"Cell must conform TRAutocompletionCell");
    UITableViewCell <TRAutocompletionCell> *completionCell = (UITableViewCell <TRAutocompletionCell> *) cell;

    id suggestion = self.suggestions[(NSUInteger) indexPath.row];
    NSAssert([suggestion conformsToProtocol:@protocol(TRSuggestionItem)], @"Suggestion item must conform TRSuggestionItem");
    id <TRSuggestionItem> suggestionItem = (id <TRSuggestionItem>) suggestion;

    // Always default to None for potential dequed cells (IE, changing search results)
    if (!self.selectedSuggestion) {
        completionCell.accessoryType = UITableViewCellAccessoryNone;
    }
    // Selected suggestion can be set before table is displayed from previously selected item
    else {
        // Choices match directly
        BOOL choiceMatch = (self.selectedSuggestion == suggestionItem);
        if (choiceMatch) {
            completionCell.accessoryType = UITableViewCellAccessoryCheckmark;
        }

        // Relationships need objectIdentifer comparison
        BOOL relationshipSelector = [suggestionItem respondsToSelector:@selector(objectIdentifier)];
        if (relationshipSelector && [[suggestionItem objectIdentifier] isEqualToNumber:[self.selectedSuggestion objectIdentifier]]) {
            completionCell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
        else {
            completionCell.accessoryType = UITableViewCellAccessoryNone;
        }
    }

    // set cell's textLabel to item's completionText
    [completionCell updateWith:suggestionItem];

    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self selectMatch:indexPath.row];
}

#pragma mark - Selection utlity methods

- (BOOL)selectSingleMatch
{
    return NO;
}

- (void)selectMatch:(NSUInteger)row
{
    id suggestion = self.suggestions[(NSUInteger)row];
    NSAssert([suggestion conformsToProtocol:@protocol(TRSuggestionItem)], @"Suggestion item must conform TRSuggestionItem");

    self.selectedSuggestion = (id <TRSuggestionItem>) suggestion;
    
    if (self.autocompletionBlock)
        self.autocompletionBlock(self.selectedSuggestion);
    
    _queryTextField.text = self.selectedSuggestion.completionText;
    [_queryTextField resignFirstResponder];
}

#pragma mark - Text field delegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    // Maintain a reference to the previous query text
    _previousQueryText = [textField.text stringByReplacingCharactersInRange:range withString:string];

    SEL queryChangedWithTextField = @selector(queryChangedWithTextField);

    // Cancel the previous search request
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:queryChangedWithTextField object:nil];

    // Perform the search in 0.25s; if the user enters addition data then this search will be cancelled by the previous line
    [self performSelector:queryChangedWithTextField withObject:nil afterDelay:0.25];

    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    // if 'Clear' button is touched in search bar, we need to re-trigger search
    [self queryChangedWithTextField];

    return YES;
}

#pragma mark - Utility methods

- (BOOL)isSearchTextField
{
    return [_queryTextField isKindOfClass:NSClassFromString(@"UISearchBarTextField")];
}

CGFloat StatusBarHeight()
{
    CGSize statusBarSize = [[UIApplication sharedApplication] statusBarFrame].size;
    return MIN(statusBarSize.width, statusBarSize.height);
}

#pragma mark - Memory management

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:UIKeyboardWillShowNotification
     object:nil];
}

@end
