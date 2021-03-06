//
//  MainMenuViewController.m
//  EVEUniverse
//
//  Created by Artem Shimanski on 9/3/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "MainMenuViewController.h"
#import "ItemsDBViewController.h"
#import "MarketGroupsViewController.h"
#import "SelectCharacterBarButtonItem.h"
#import "SkillsViewController.h"
#import "EVEAccount.h"
#import "EVEOnlineAPI.h"
#import "CharacterInfoViewController.h"
#import "SBTableView.h"
#import "RSSFeedsViewController.h"
#import "MainMenuCellView.h"
#import "UITableViewCell+Nib.h"
#import "Globals.h"
#import "AboutViewController.h"
#import "WalletTransactionsViewController.h"
#import "MarketOrdersViewController.h"
#import "IndustryJobsViewController.h"
#import "SplashScreenViewController.h"

@interface MainMenuViewController()
@property (nonatomic, strong) UIPopoverController* masterPopover;
@property (nonatomic, assign) NSInteger numberOfUnreadMessages;


- (void) didSelectAccount:(NSNotification*) notification;
- (IBAction) dismissModalViewController;
- (void) didReadMail:(NSNotification*) notification;
- (void) loadMail;

@end


@implementation MainMenuViewController

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}
*/


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
	self.title = NSLocalizedString(@"Home", nil);
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		[self.navigationItem setRightBarButtonItem:[SelectCharacterBarButtonItem barButtonItemWithParentViewController:self.splitViewController]];
		[self.tableView setBackgroundView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"backgroundMenu~ipad.png"]]];
	}
	else {
		[self.navigationItem setRightBarButtonItem:[SelectCharacterBarButtonItem barButtonItemWithParentViewController:self]];
		[self.tableView setBackgroundView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"background.png"]]];
	}
	
	self.menuItems = [NSArray arrayWithContentsOfURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"mainMenu" ofType:@"plist"]]];
	[self.characterInfoView addSubview:self.characterInfoViewController.view];
	self.characterInfoViewController.view.frame = self.characterInfoView.bounds;
	
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didSelectAccount:) name:NotificationSelectAccount object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didReadMail:) name:NotificationReadMail object:nil];
	self.numberOfUnreadMessages = 0;
	[self loadMail];
	self.onlineModeSegmentedControl.selectedSegmentIndex = [EVECachedURLRequest isOfflineMode] ? 1 : 0;
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
		return YES;
	else
		return UIInterfaceOrientationIsPortrait(toInterfaceOrientation);
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	[self setOnlineModeSegmentedControl:nil];
    [super viewDidUnload];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self.characterInfoViewController];
	self.characterInfoViewController = nil;
	self.menuItems = nil;
	self.characterInfoView = nil;
	self.masterPopover = nil;
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:self.characterInfoViewController];
}

- (IBAction)onFacebook:(id)sender {
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.facebook.com/groups/Neocom/"]];
}

- (IBAction)onChangeOnlineMode:(id)sender {
	[EVECachedURLRequest setOfflineMode:self.onlineModeSegmentedControl.selectedSegmentIndex == 1];
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
	return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.menuItems.count;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *cellIdentifier;
	NSDictionary *item = [self.menuItems objectAtIndex:indexPath.row];

	EVEAccount *account = [EVEAccount currentAccount];
	NSInteger charAccessMask = [[item valueForKey:@"charAccessMask"] integerValue];
	NSInteger corpAccessMask = [[item valueForKey:@"corpAccessMask"] integerValue];
	
	if ((account.charAccessMask & charAccessMask) == charAccessMask ||
		(account.corpAccessMask & corpAccessMask) == corpAccessMask)
		cellIdentifier = @"MainMenuCellView";
	else
		cellIdentifier = @"MainMenuCellViewLimited";
    
    MainMenuCellView *cell = (MainMenuCellView*) [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [MainMenuCellView cellWithNibName:@"MainMenuCellView" bundle:nil reuseIdentifier:cellIdentifier];
    }
	NSString *className = [item valueForKey:@"className"];

	if (self.numberOfUnreadMessages > 0 && [className isEqualToString:@"MessagesViewController"]) {
		cell.titleLabel.text = [NSString stringWithFormat:@"%@ (%d)", NSLocalizedString([item valueForKey:@"title"], nil), self.numberOfUnreadMessages];
	}
	else {
		cell.titleLabel.text = NSLocalizedString([item valueForKey:@"title"], nil);
	}
	cell.iconImageView.image = [UIImage imageNamed:[item valueForKey:@"image"]];
    return cell;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	NSDictionary *item = [self.menuItems objectAtIndex:indexPath.row];

	EVEAccount *account = [EVEAccount currentAccount];
	NSInteger charAccessMask = [[item valueForKey:@"charAccessMask"] integerValue];
	NSInteger corpAccessMask = [[item valueForKey:@"corpAccessMask"] integerValue];
	
	if ((account.charAccessMask & charAccessMask) != charAccessMask &&
		(account.corpAccessMask & corpAccessMask) != corpAccessMask)
		return;

	NSString *className = [item valueForKey:@"className"];
	NSString *nibName = [item valueForKey:@"nibName"];
	Class class = NSClassFromString(className);
	if (!class)
		return;

	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
		if ([[item valueForKey:@"modal"] boolValue]) {
			UIViewController *controller = [[NSClassFromString(className) alloc] initWithNibName:nibName bundle:nil];
			UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:controller];
			[navController.navigationBar setBarStyle:UIBarStyleBlackOpaque];
			navController.modalPresentationStyle = UIModalPresentationFormSheet;
			[controller.navigationItem setLeftBarButtonItem:[[UIBarButtonItem alloc] initWithTitle:@"Close" style:UIBarButtonItemStyleBordered target:self action:@selector(dismissModalViewController)]];
			[self.splitViewController presentModalViewController:navController animated:YES];
		}
		else {
			NSArray *viewControllers = [self.splitViewController viewControllers];
			UINavigationController *navController = [viewControllers objectAtIndex:1];
			if ([[[[navController viewControllers] objectAtIndex:0] class] isEqual:class])
				[navController popToRootViewControllerAnimated:YES];
			else {
				UIViewController *controller = [[NSClassFromString(className) alloc] initWithNibName:nibName bundle:nil];
				navController = [[UINavigationController alloc] initWithRootViewController:controller];
				[navController.navigationBar setBarStyle:UIBarStyleBlackOpaque];
				if (self.masterPopover) {
					UINavigationController* navigationController = [[self.splitViewController viewControllers] objectAtIndex:1];
					controller.navigationItem.leftBarButtonItem = [[[[navigationController viewControllers] objectAtIndex:0] navigationItem] leftBarButtonItem];
					[self.masterPopover dismissPopoverAnimated:YES];
				}
				[self.splitViewController setViewControllers:[NSArray arrayWithObjects:[viewControllers objectAtIndex:0], navController, nil]];
			}
		}
	}
	else {
		UIViewController *controller = [[NSClassFromString(className) alloc] initWithNibName:nibName bundle:nil];
		[self.navigationController pushViewController:controller animated:YES];
	}
	
	return;
}

#pragma mark - UIScrollViewDelegate

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
	CGRect frame = self.characterInfoView.frame;
	if (scrollView.contentOffset.y < 0)
		frame.origin.y = scrollView.contentOffset.y;
	else if (scrollView.contentOffset.y < self.characterInfoView.frame.size.height - 24)
		frame.origin.y = 0;
	else
		frame.origin.y = scrollView.contentOffset.y - self.characterInfoView.frame.size.height + 24;
	self.characterInfoView.frame = frame;
}

#pragma mark CharacterInfoViewControllerDelegate

- (void) characterInfoViewController:(CharacterInfoViewController*) controller willChangeContentSize:(CGSize) size animated:(BOOL) animated{
	if (animated) {
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:0.5];
		[UIView setAnimationBeginsFromCurrentState:YES];
	}
	self.tableView.tableHeaderView.frame = CGRectMake(0, 0, size.width, size.height + 40);
	self.tableView.tableHeaderView = self.tableView.tableHeaderView;

	self.characterInfoView.frame = CGRectMake(0, 0, size.width, size.height);
	[self scrollViewDidScroll:self.tableView];

	if (animated)
		[UIView commitAnimations];
}

#pragma mark ADBannerViewDelegate

- (void)bannerViewDidLoadAd:(ADBannerView *)banner {
}

- (void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error {
}

- (BOOL)bannerViewActionShouldBegin:(ADBannerView *)banner willLeaveApplication:(BOOL)willLeave {
	return YES;
}

- (void)bannerViewActionDidFinish:(ADBannerView *)banner {
}

#pragma mark - UISplitViewControllerDelegate

- (void)splitViewController:(UISplitViewController *)svc willHideViewController:(UIViewController *)aViewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)pc {
	barButtonItem.title = NSLocalizedString(@"Menu", nil);
	UINavigationController* navigationController = [[self.splitViewController viewControllers] objectAtIndex:1];
	[[[[navigationController viewControllers] objectAtIndex:0] navigationItem] setLeftBarButtonItem:barButtonItem animated:YES];
	self.masterPopover = pc;
}

- (void)splitViewController:(UISplitViewController *)svc willShowViewController:(UIViewController *)aViewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem {
	UINavigationController* navigationController = [[self.splitViewController viewControllers] objectAtIndex:1];
	[[[[navigationController viewControllers] objectAtIndex:0] navigationItem] setLeftBarButtonItem:nil animated:YES];
	self.masterPopover = nil;
}

#pragma mark - Private

- (void) didSelectAccount:(NSNotification*) notification {
	self.numberOfUnreadMessages = 0;
	[self.tableView reloadData];
	[self loadMail];
}

- (IBAction) dismissModalViewController {
	[self.splitViewController dismissModalViewControllerAnimated:YES];
}

- (void) didReadMail:(NSNotification*) notification {
	[self loadMail];
}

- (void) loadMail {
	EVEAccount* currentAccount = [EVEAccount currentAccount];
	if (currentAccount) {
		EUOperation *operation = [EUOperation operationWithIdentifier:@"MainMenuViewController+CheckMail" name:NSLocalizedString(@"Checking Mail", nil)];
		[operation addExecutionBlock:^(void) {
			@autoreleasepool {
				self.numberOfUnreadMessages = [[currentAccount mailBox] numberOfUnreadMessages];
			}
		}];
		
		__weak EUOperation* weakOperation = operation;
		[operation setCompletionBlockInCurrentThread:^(void) {
			if (![weakOperation isCancelled])
				[self.tableView reloadData];
		}];
		
		[[EUOperationQueue sharedQueue] addOperation:operation];
	}
}

@end
