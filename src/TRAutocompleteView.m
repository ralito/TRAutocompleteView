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
#import "UIScrollView+infiniteScrolling.h"

#define UIViewAutoresizingFlexibleMargins   \
UIViewAutoresizingFlexibleBottomMargin    | \
UIViewAutoresizingFlexibleLeftMargin      | \
UIViewAutoresizingFlexibleRightMargin     | \
UIViewAutoresizingFlexibleTopMargin

static const CGFloat AUTOCOMPLETE_CELL_HEIGHT = 64.0f;

@interface TRAutocompleteView () <UITableViewDelegate, UITableViewDataSource>

@property(readwrite) id <TRSuggestionItem> selectedSuggestion;
@property(readwrite) NSMutableArray *suggestions;
@property (nonatomic, readwrite) TRInfiniteScrollingState state;
@property (nonatomic, copy) void (^infiniteScrollingHandler)(void);


- (BOOL)isSearchTextField;

@end

@implementation TRAutocompleteView
{
    BOOL _visible;
    
    __weak UITextField *_queryTextField;
    __weak UIViewController *_contextController;
    
    UITableView *_table;
    id <TRAutocompleteItemsSource> _itemsSource;
    id <TRAutocompletionCellFactory> _cellFactory;
    
    SuggestionsList* suggestionsList;
}

@synthesize suggestionMode;
@synthesize autocompletionBlock;

+ (TRAutocompleteView *)autocompleteViewBindedTo:(UITextField *)textField
                                     usingSource:(id <TRAutocompleteItemsSource>)itemsSource
                                     cellFactory:(id <TRAutocompletionCellFactory>)factory
                                    presentingIn:(UIViewController *)controller withMode:(SuggestionMode)mode
                               whenSelectionMade:(didAutocompletionBlock)autocompleteBlock
{
    return [[TRAutocompleteView alloc] initWithFrame:CGRectZero
                                           textField:textField
                                         itemsSource:itemsSource
                                         cellFactory:factory
                                          controller:controller withMode:mode
                                   whenSelectionMade:autocompleteBlock
            ];
}

- (id)initWithFrame:(CGRect)frame
          textField:(UITextField *)textField
        itemsSource:(id <TRAutocompleteItemsSource>)itemsSource
        cellFactory:(id <TRAutocompletionCellFactory>)factory
         controller:(UIViewController *)controller withMode:(SuggestionMode)mode whenSelectionMade:(didAutocompletionBlock)autocompleteBlock_
{
    self = [super initWithFrame:frame];
    suggestionMode = mode;
    
    _queryTextField = textField;
    _itemsSource = itemsSource;
    _cellFactory = factory;
    _contextController = controller;
    autocompletionBlock=autocompleteBlock_;
    self.suggestions = [NSMutableArray new];
    suggestionsList.suggestionsArray = nil;
    
    if (self) {
        if (mode==Normal) {

            // Preset appearance and autoresizing setup
            [self loadDefaults];
            
            // Initialize and configure table view
            [self setupTableView];

            // Add _table to autocompleteView to configure constraints
            [self addSubview:_table];
            [self addConstraints:[NSLayoutConstraint
                                       constraintsWithVisualFormat:@"H:|-0-[_table]-0-|"
                                       options:NSLayoutFormatDirectionLeadingToTrailing
                                       metrics:nil
                                       views:NSDictionaryOfVariableBindings(_table)]];
            [self addConstraints:[NSLayoutConstraint
                                       constraintsWithVisualFormat:@"V:|-0-[_table]-0-|"
                                       options:NSLayoutFormatDirectionLeadingToTrailing
                                       metrics:nil
                                       views:NSDictionaryOfVariableBindings(_table)]];
        } else {
            suggestionsList = [[SuggestionsList alloc] initWithAutocompleteItemSource:_itemsSource andAutocompletionBlock:autocompleteBlock_ withCellFont:_cellFactory.cellFont];
        }
        
        // Setup action for callback when new search query returns results
        [_queryTextField addTarget:self action:@selector(queryChanged:) forControlEvents:UIControlEventEditingChanged];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillBeShown:)
                                                     name:UIKeyboardWillShowNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillHide:)
                                                     name:UIKeyboardWillHideNotification
                                                   object:nil];
    }
    
    return self;
}

#pragma mark - View setup

- (void)loadDefaults
{
    self.backgroundColor = [UIColor whiteColor];
    self.separatorColor = [UIColor lightGrayColor];
    self.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    self.topMargin = 0;

    self.autoresizingMask = UIViewAutoresizingFlexibleMargins;
    self.state = TRInfiniteScrollingStateStopped;
}

- (void)setupTableView
{
    _table = [[UITableView alloc] initWithFrame:self.frame style:UITableViewStylePlain];
    _table.backgroundColor = [UIColor clearColor];
    _table.separatorColor = self.separatorColor;
    _table.separatorStyle = self.separatorStyle;
    _table.delegate = self;
    _table.dataSource = self;
    self.originalBottomInset = _table.contentInset.bottom;

    // Enable scrolling and slight padding @ bottom of table view
    UIEdgeInsets edgeInsets = UIEdgeInsetsMake(0, 0, 10, 0);
    [_table setContentInset:edgeInsets];
    [_table setScrollIndicatorInsets:edgeInsets];
    _table.translatesAutoresizingMaskIntoConstraints = NO;
}

#pragma mark - Actions

- (void)queryChanged:(id)sender
{
    // TODO: Make usable if existing search vs. new search
    __block NSMutableArray *existingSuggestions = [self.suggestions mutableCopy];

    if ([_queryTextField.text length] >= _itemsSource.minimumCharactersToTrigger) {
        [_itemsSource itemsFor:_queryTextField.text withOffset:existingSuggestions.count whenReady:
         ^(NSArray *suggestions)
         {
             self.state = TRInfiniteScrollingStateStopped;
             
             if (_queryTextField.text.length
                 < _itemsSource.minimumCharactersToTrigger) {
                 self.suggestions = nil;
                 if (suggestionMode==Normal)
                     [_table reloadData];
                 else {
                     suggestionsList.suggestionsArray=self.suggestions;
                 }
             }
             else {
                 // TODO: Make usable if existing search vs. new search
                 existingSuggestions = suggestions;
                 [existingSuggestions addObjectsFromArray:suggestions];
                 self.suggestions = existingSuggestions;

                 if (suggestionMode==Normal) {
                     // Scanner used and one suggestion matched scanned code, so select match
                     if (self.suggestions.count == 1) {
                         [self selectMatch:0];
                     }
                     else {
                         [_table reloadData];

                         // show suggestions table view
                         if (self.suggestions.count > 0 && !_visible) {
                             [_contextController.view addSubview:self];
                             _visible = YES;
                         }
                     }
                 } else {
                     // show popover
                     if (self.suggestions.count > 0) {
                         suggestionsList.suggestionsArray=self.suggestions;
                         [suggestionsList showSuggestionsFor:_queryTextField];
                     }
                 }
             }
         }];
    }
    else
    {
        self.suggestions = nil;
        [_table reloadData];
    }
}

- (void)queryChangedWithSuccessBlock:(void (^)(NSArray *suggestions))successBlock
{
    if ([_queryTextField.text length] >= _itemsSource.minimumCharactersToTrigger) {
        [_itemsSource itemsFor:_queryTextField.text withOffset:0 whenReady:
         ^(NSArray *suggestions)
         {
             self.state = TRInfiniteScrollingStateStopped;

             self.suggestions = suggestions;
             
             if (suggestionMode==Normal) {
                 // Scanner used and one suggestion matched scanned code, so select match
                 if (self.suggestions.count == 1) {                    
                      successBlock(self.suggestions);
                 }
                 else {
                     [_table reloadData];
                     
                     // show suggestions table view
                     if (self.suggestions.count > 0 && !_visible) {
                         [_contextController.view addSubview:self];
                         _visible = YES;
                     }
                     successBlock(self.suggestions);
                 }
             }
         }];
    }
    else {
        self.suggestions = nil;
        [_table reloadData];
    }
}

#pragma mark - Keyboard notification methods

- (void)keyboardWillBeShown:(NSNotification *)notification
{
    if (suggestionMode==Normal) {
        BOOL isIPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);

        CGRect controlFrame;
        // Forces table view to entire width of view
        // inheriting from the size of the UISearchBar included in the view controller
        if ([self isSearchTextField]) {
            controlFrame = _queryTextField.superview.frame;
        }
        else {
            controlFrame = _queryTextField.frame;
        }

        // All calculations below are to determine autocompleteView's frame,
        // considering orientation and position of controlFrame (textField), statusBar,
        // and keyboard height.
        NSDictionary *info = [notification userInfo];
        CGSize kbSize = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;

        CGFloat contextViewHeight = _contextController.view.frame.size.height;
        CGFloat calculatedY = controlFrame.origin.y + controlFrame.size.height + (isIPad ? 0 : StatusBarHeight());
        CGFloat calculatedHeight = contextViewHeight - calculatedY - kbSize.height;

        // Multiplier for dynamic height of iPad's FormSheet to resize view/tableView frame
        if (isIPad)
            calculatedHeight *= 1.6;

        // Keyboard displayed over the top of TabBarController,
        // so need to also add padding to height
        calculatedHeight += _contextController.tabBarController.tabBar.frame.size.height;

        self.frame = CGRectMake(controlFrame.origin.x,
                                calculatedY,
                                _contextController.view.frame.size.width,
                                calculatedHeight);
        _table.contentSize = CGSizeMake(self.frame.size.width, self.frame.size.height);
    }
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    if (suggestionMode == Popover) {
        [self removeFromSuperview];
        _visible = NO;
    }
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.suggestions.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return AUTOCOMPLETE_CELL_HEIGHT;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"TRAutocompleteCell";
    
    id cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (cell == nil)
        cell = [_cellFactory createReusableCellWithIdentifier:identifier];
    
    NSAssert([cell isKindOfClass:[UITableViewCell class]], @"Cell must inherit from UITableViewCell");
    NSAssert([cell conformsToProtocol:@protocol(TRAutocompletionCell)], @"Cell must conform TRAutocompletionCell");
    UITableViewCell <TRAutocompletionCell> *completionCell = (UITableViewCell <TRAutocompletionCell> *) cell;
    
    id suggestion = self.suggestions[(NSUInteger) indexPath.row];
    NSAssert([suggestion conformsToProtocol:@protocol(TRSuggestionItem)], @"Suggestion item must conform TRSuggestionItem");
    id <TRSuggestionItem> suggestionItem = (id <TRSuggestionItem>) suggestion;
    
    [completionCell updateWith:suggestionItem];
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self selectMatch:indexPath.row];
}

#pragma mark - Scroll view delegate

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"contentOffset"])
        [self scrollViewDidScroll:_table];
    else if([keyPath isEqualToString:@"contentSize"]) {
        [self layoutSubviews];
        self.frame = CGRectMake(0, _table.contentSize.height, _table.bounds.size.width, 60);
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGPoint contentOffset = _table.contentOffset;
    if (self.state != TRInfiniteScrollingStateLoading) {
        CGFloat scrollViewContentHeight = _table.contentSize.height;
        CGFloat scrollOffsetThreshold = scrollViewContentHeight - _table.bounds.size.height;

        if (!_table.isDragging  && self.state == TRInfiniteScrollingStateTriggered) {
            // loading
            self.state = TRInfiniteScrollingStateLoading;
            NSLog(@"loading data...");
        }
        else if(contentOffset.y > scrollOffsetThreshold  && self.state == TRInfiniteScrollingStateStopped && _table.isDragging) {
            // trigger
            self.state = TRInfiniteScrollingStateTriggered;
            NSLog(@"Should trigger new load of data...");
            [self queryChanged:nil];
        }
        else if(contentOffset.y < scrollOffsetThreshold && self.state != TRInfiniteScrollingStateStopped) {
            // stopped
            self.state = TRInfiniteScrollingStateStopped;
            NSLog(@"stopped dragging");
        }
    }
}

- (void)setState:(TRInfiniteScrollingState)newState {
    
    if(_state == newState)
        return;
    
    TRInfiniteScrollingState previousState = _state;
    _state = newState;

    switch (newState) {
        case TRInfiniteScrollingStateStopped:
            break;
            
        case TRInfiniteScrollingStateTriggered:
            break;
            
        case TRInfiniteScrollingStateLoading:
            break;
    }
    
    if (previousState == TRInfiniteScrollingStateTriggered && newState == TRInfiniteScrollingStateLoading && self.infiniteScrollingHandler) {
        NSLog(@"FETCH NEW RESULTS");
        self.infiniteScrollingHandler();
    }
}

#pragma mark - Selection utlity methods

- (BOOL)selectSingleMatch
{
    if (suggestionsList.matchedSuggestions.count==1){
        
        [self selectMatch:0];
        [suggestionsList.popOver dismissPopoverAnimated:YES];
        
        return YES;
    }
    if (suggestionsList.matchedSuggestions.count>1) {
        return NO;
    }
    
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
    [_queryTextField removeTarget:self action:@selector(queryChanged:) forControlEvents:UIControlEventEditingChanged];

    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:UIKeyboardWillShowNotification
     object:nil];

    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:UIKeyboardWillHideNotification
     object:nil];
}

@end
