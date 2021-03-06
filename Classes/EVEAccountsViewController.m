//
//  EVEAccountsViewController.m
//  EVEUniverse
//
//  Created by Artem Shimanski on 9/2/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "EVEAccountsViewController.h"
#import "Globals.h"
#import "AddEVEAccountViewController.h"
#import "EVEAccount.h"
#import "EVEOnlineAPI.h"
#import "EVEAccountsAPIKeyCellView.h"
#import "EVEAccountsCharacterCellView.h"
#import "UITableViewCell+Nib.h"
#import "EVEUniverseAppDelegate.h"
#import "NSString+TimeLeft.h"
#import "AccessMaskViewController.h"
#import "UIImageView+URL.h"
#import "EUStorage.h"

@interface EVEAccountsViewController()
@property (nonatomic, strong) NSMutableArray *sections;
@property (nonatomic, strong) NSOperation *loadingOperation;

- (void) loadSection:(NSMutableDictionary*) section;
- (void) accountStorageDidChange:(NSNotification*) notification;
- (void) reload;
- (void) didUpdateCloud:(NSNotification*) notification;
@end


@implementation EVEAccountsViewController

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
	[self.tableView setBackgroundView:[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"background.png"]]];
	self.title = NSLocalizedString(@"Accounts", nil);
	[self.navigationItem setRightBarButtonItem:self.editButtonItem];
	self.logoffButton.hidden = [EVEAccount currentAccount] == nil;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accountStorageDidChange:) name:NotificationAccountStoargeDidChange object:nil];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
		return YES;
	else
		return UIInterfaceOrientationIsPortrait(toInterfaceOrientation);
}

- (void)viewDidUnload {
    [super viewDidUnload];
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	self.logoffButton = nil;
	self.sections = nil;
	self.loadingOperation = nil;
}

- (void) viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self reload];
}

- (void) viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self.loadingOperation cancel];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (IBAction) onAddAccount: (id) sender {
	AddEVEAccountViewController *controller = [[AddEVEAccountViewController alloc] initWithNibName:@"AddEVEAccountViewController" bundle:nil];
	[self.navigationController pushViewController:controller animated:YES];
}

- (IBAction) onLogoff: (id) sender {
	[[EVEAccount currentAccount] logoff];
	[self.navigationController dismissModalViewControllerAnimated:YES];
}

- (void) setEditing:(BOOL)editing animated:(BOOL)animated {
	[super setEditing:editing animated:animated];
	[self.tableView setEditing:editing animated:animated];
	NSMutableIndexSet *indexes = [NSMutableIndexSet indexSet];
	int sectionIndex = 0;
	for (NSDictionary *section in self.sections) {
		EVEAccountStorageCharacter *character = [section valueForKey:@"character"];
		if (character && !character.enabled) {
			[indexes addIndex:sectionIndex]; 
		}
		sectionIndex++;
	}
	[self.tableView reloadSections:indexes withRowAnimation:UITableViewRowAnimationFade];
	if (!self.editing) {
		EUStorage* storage = [EUStorage sharedStorage];
		[storage saveContext];
	}
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
	return self.sections.count;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	NSDictionary *sectionDic = [self.sections objectAtIndex:section];
	EVEAccountStorageCharacter *character = [sectionDic valueForKey:@"character"];
	if (character) {
		if (self.editing || character.enabled)
			return [[sectionDic valueForKey:@"apiKeys"] count] + 1;
		else
			return 0;
	}
	else
		return [[sectionDic valueForKey:@"apiKeys"] count];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *section = [self.sections objectAtIndex:indexPath.section];
	EVEAccountStorageCharacter *character = [section valueForKey:@"character"];
	if (character && indexPath.row == 0) {
		static NSString *cellIdentifier = @"EVEAccountsCharacterCellView";
		
		EVEAccountsCharacterCellView *cell = (EVEAccountsCharacterCellView*) [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (cell == nil) {
			cell = [EVEAccountsCharacterCellView cellWithNibName:@"EVEAccountsCharacterCellView" bundle:nil reuseIdentifier:cellIdentifier];
		}
		
		if (RETINA_DISPLAY) {
			[cell.portraitImageView setImageWithContentsOfURL:[EVEImage characterPortraitURLWithCharacterID:character.characterID size:EVEImageSize128 error:nil] scale:2.0 completion:nil failureBlock:nil];
			[cell.corpImageView setImageWithContentsOfURL:[EVEImage corporationLogoURLWithCorporationID:character.corporationID size:EVEImageSize64 error:nil] scale:2.0 completion:nil failureBlock:nil];
		}
		else {
			[cell.portraitImageView setImageWithContentsOfURL:[EVEImage characterPortraitURLWithCharacterID:character.characterID size:EVEImageSize64 error:nil] scale:1.0 completion:nil failureBlock:nil];
			[cell.corpImageView setImageWithContentsOfURL:[EVEImage corporationLogoURLWithCorporationID:character.corporationID size:EVEImageSize32 error:nil] scale:1.0 completion:nil failureBlock:nil];
		}
		cell.userNameLabel.text = character.characterName;
		cell.corpLabel.text = character.corporationName;
		
		cell.character = character;
		UIColor *color;

		cell.trainingTimeLabel.text = [section valueForKey:@"trainingTime"];
		color = [section valueForKey:@"trainingTimeColor"];
		if (color)
			cell.trainingTimeLabel.textColor = color;
		
		cell.paidUntilLabel.text = [section valueForKey:@"paidUntil"];
		color = [section valueForKey:@"paidUntilColor"];
		if (color)
			cell.paidUntilLabel.textColor = color;

		NSString* location = [section valueForKey:@"location"];
		NSString* wealth = [section valueForKey:@"wealth"];
		if (wealth) {
			cell.wealthLabel.text = wealth;
			cell.locationLabel.text = location;
		}
		else {
			cell.wealthLabel.text = location;
			cell.locationLabel.text = nil;
		}
		
		return cell;
	}
	else {
		EVEAccountStorageAPIKey *apiKey = [[section valueForKey:@"apiKeys"] objectAtIndex:indexPath.row - (character ? 1 : 0)];
		
		NSString *cellIdentifier = apiKey.error ? @"EVEAccountsAPIKeyCellViewError" : @"EVEAccountsAPIKeyCellView";

		
		EVEAccountsAPIKeyCellView *cell = (EVEAccountsAPIKeyCellView*) [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (cell == nil) {
			cell = [EVEAccountsAPIKeyCellView cellWithNibName:@"EVEAccountsAPIKeyCellView" bundle:nil reuseIdentifier:cellIdentifier];
		}
		cell.accessMaskLabel.text = [NSString stringWithFormat:@"%d", apiKey.apiKeyInfo.key.accessMask];
		cell.keyIDLabel.text = [NSString stringWithFormat:@"%d", apiKey.keyID];
		cell.topSeparator.hidden = indexPath.row > 0;
		if (apiKey.error) {
			cell.errorLabel.text = [apiKey.error localizedDescription];
		}
		else {
			cell.keyTypeLabel.text = apiKey.apiKeyInfo.key.type == EVEAPIKeyTypeCorporation ? NSLocalizedString(@"Corporation", nil) : NSLocalizedString(@"Character", nil);
			if (apiKey.apiKeyInfo.key.expires) {
				NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
				[dateFormatter setDateFormat:@"yyyy.MM.dd"];
				cell.expiredLabel.text = [dateFormatter stringFromDate:apiKey.apiKeyInfo.key.expires];
			}
			else
				cell.expiredLabel.text = @"-";
		}
		return cell;
	}
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (UITableViewCellEditingStyleDelete) {
		NSDictionary *sectionDic = [self.sections objectAtIndex:indexPath.section];
		EVEAccountStorageCharacter *character = [sectionDic valueForKey:@"character"];
		EVEAccountStorageAPIKey *apiKey = [[sectionDic valueForKey:@"apiKeys"] objectAtIndex:indexPath.row - (character ? 1 : 0)];
		[tableView beginUpdates];
		
		NSInteger sectionIndex = 0;
		for (NSDictionary *section in [NSArray arrayWithArray:self.sections]) {
			NSMutableArray *apiKeys = [section valueForKey:@"apiKeys"];
			NSInteger index = [apiKeys indexOfObject:apiKey];
			if (index != NSNotFound) {
				[apiKeys removeObjectAtIndex:index];
				if (apiKeys.count == 0) {
					[tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
					[self.sections removeObject:section];
				}
				else {
					NSInteger rowIndex = index + ([section valueForKey:@"character"] ? 1 : 0);
					[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:rowIndex inSection:sectionIndex]] withRowAnimation:UITableViewRowAnimationFade];
				}
			}
			sectionIndex++;
		}
		[[EVEAccountStorage sharedAccountStorage] removeAPIKey:apiKey.keyID];
		
		[tableView endUpdates];
	}
}

#pragma mark -
#pragma mark Table view delegate

- (BOOL) tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.row > 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *sectionDic = [self.sections objectAtIndex:indexPath.section];
	EVEAccountStorageCharacter *character = [sectionDic valueForKey:@"character"];
	if (character && indexPath.row == 0)
		return 128;
	else
		return 40;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *section = [self.sections objectAtIndex:indexPath.section];
	EVEAccountStorageCharacter *character = [section valueForKey:@"character"];
	if (character && indexPath.row == 0) {
		[[EVEAccount accountWithCharacter:character] login];
		[self.navigationController dismissModalViewControllerAnimated:YES];
	}
	else {
		EVEAccountStorageAPIKey *apiKey = [[section valueForKey:@"apiKeys"] objectAtIndex:indexPath.row - (character ? 1 : 0)];
		if (apiKey && !apiKey.error) {
			AccessMaskViewController *controller = [[AccessMaskViewController alloc] initWithNibName:@"AccessMaskViewController" bundle:nil];
			controller.accessMask = apiKey.apiKeyInfo.key.accessMask;
			controller.corporate = apiKey.apiKeyInfo.key.type == EVEAPIKeyTypeCorporation;
			[self.navigationController pushViewController:controller animated:YES];
		}
	}
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSDictionary *sectionDic = [self.sections objectAtIndex:indexPath.section];
	EVEAccountStorageCharacter *character = [sectionDic valueForKey:@"character"];
	if (character && indexPath.row == 0)
		return UITableViewCellEditingStyleNone;
	else
		return UITableViewCellEditingStyleDelete;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	UIView *footer = [[UIView alloc] initWithFrame:CGRectZero];
	footer.opaque = NO;
	footer.backgroundColor = [UIColor clearColor];
	return footer;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSDictionary *sectionDic = [self.sections objectAtIndex:section];
	EVEAccountStorageCharacter *character = [sectionDic valueForKey:@"character"];
	if (character) {
		if (self.editing || character.enabled)
			return 10;
		else
			return 0;
	}
	else
		return [[sectionDic valueForKey:@"apiKeys"] count] > 0 ? 10 : 0;
}

#pragma mark - Private

- (void) loadSection:(NSMutableDictionary*) section {
	EVEAccountStorageCharacter *character = [section valueForKey:@"character"];
	
	if (character) {
		EVEAccountStorageAPIKey *apiKey = [character anyCharAPIKey];
		if (!apiKey) {
		}
		else {
			NSError *error = nil;
			EVEAccountStatus *accountStatus = [EVEAccountStatus accountStatusWithKeyID:apiKey.keyID vCode:apiKey.vCode error:&error progressHandler:nil];
			if (error) {
				[section setValue:[error localizedDescription] forKey:@"paidUntil"];
				[section setValue:[UIColor whiteColor] forKey:@"paidUntilColor"];
			}
			else {
				UIColor *color;
				NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
				[dateFormatter setDateFormat:@"yyyy-MM-dd"];
				int days = [accountStatus.paidUntil timeIntervalSinceNow] / (60 * 60 * 24);
				if (days < 0)
					days = 0;
				if (days > 7)
					color = [UIColor greenColor];
				else if (days == 0)
					color = [UIColor redColor];
				else
					color = [UIColor yellowColor];
				[section setValue:[NSString stringWithFormat:NSLocalizedString(@"%@ (%d days remaining)", nil), [dateFormatter stringFromDate:accountStatus.paidUntil], days]
						   forKey:@"paidUntil"];
				[section setValue:color forKey:@"paidUntilColor"];
			}
			
			EVESkillQueue *skillQueue = [EVESkillQueue skillQueueWithKeyID:apiKey.keyID vCode:apiKey.vCode characterID:character.characterID error:&error progressHandler:nil];
			if (error) {
				[section setValue:[error localizedDescription] forKey:@"trainingTime"];
				[section setValue:[UIColor whiteColor] forKey:@"trainingTimeColor"];
			}
			else {
				NSString *text;
				UIColor *color = nil;
				if (skillQueue.skillQueue.count > 0) {
					NSDate *endTime = [[skillQueue.skillQueue lastObject] endTime];
					NSTimeInterval timeLeft = [endTime timeIntervalSinceDate:[skillQueue serverTimeWithLocalTime:[NSDate date]]];
					if (timeLeft > 3600 * 24)
						color = [UIColor greenColor];
					else
						color = [UIColor yellowColor];
					text = [NSString stringWithFormat:NSLocalizedString(@"%@ (%d skills in queue)", nil), [NSString stringWithTimeLeft:timeLeft], skillQueue.skillQueue.count];
				}
				else {
					text = NSLocalizedString(@"Training queue is inactive", nil);
					color = [UIColor redColor];
				}
				[section setValue:text forKeyPath:@"trainingTime"];
				[section setValue:color forKeyPath:@"trainingTimeColor"];
			}
			
			EVECharacterInfo* characterInfo = [EVECharacterInfo characterInfoWithKeyID:apiKey.keyID vCode:apiKey.vCode characterID:character.characterID error:&error progressHandler:nil];
			if (characterInfo.lastKnownLocation) {
				[section setValue:[NSString stringWithFormat:NSLocalizedString(@"Location: %@", nil), characterInfo.lastKnownLocation]
						   forKey:@"location"];
			}
			EVEAccountBalance* accountBalance = [EVEAccountBalance accountBalanceWithKeyID:apiKey.keyID vCode:apiKey.vCode characterID:character.characterID corporate:NO error:&error progressHandler:nil];
			if (accountBalance && accountBalance.accounts.count > 0) {
				float balance = [[accountBalance.accounts objectAtIndex:0] balance];
				NSString* wealth = [NSString stringWithFormat:NSLocalizedString(@"%@ ISK", nil), [NSNumberFormatter localizedStringFromNumber:@(balance) numberStyle:NSNumberFormatterDecimalStyle]];
				[section setValue:wealth forKey:@"wealth"];
			}
		}
	}
	else {
	}
}

- (void) accountStorageDidChange:(NSNotification*) notification {
	if (self.navigationController.visibleViewController == self)
		[self reload];
}

- (void) reload {
	NSMutableArray *sectionsTmp = [NSMutableArray array];
	NSMutableArray *emptyKeysTmp = [NSMutableArray array];
	
	__block EUOperation *operation = [EUOperation operationWithIdentifier:@"EVEAccountsViewController+Load" name:NSLocalizedString(@"Loading Accounts", nil)];
	__weak EUOperation* weakOperation = operation;
	[operation addExecutionBlock:^(void) {
		if ([weakOperation isCancelled]) {
			return;
		}
		
		self.loadingOperation = weakOperation;
		
		EVEAccountStorage *accountStorage = [EVEAccountStorage sharedAccountStorage];
		[accountStorage reload];
		weakOperation.progress = 0.3;
		
		NSOperationQueue *queue = [[NSOperationQueue alloc] init];
		
		for (EVEAccountStorageCharacter *character in [accountStorage.characters allValues]) {
			if ([weakOperation isCancelled])
				break;
			
			NSMutableDictionary *section = [NSMutableDictionary dictionaryWithObject:character forKey:@"character"];
			NSMutableArray *apiKeys = [NSMutableArray arrayWithArray:character.assignedCharAPIKeys];
			[apiKeys addObjectsFromArray:character.assignedCorpAPIKeys];
			[section setValue:apiKeys forKey:@"apiKeys"];
			
			[sectionsTmp addObject:section];
			[queue addOperationWithBlock:^(void) {
				@autoreleasepool {
					[self loadSection:section];
				}
			}];
		}

		weakOperation.progress = 0.6;
		
		for (EVEAccountStorageAPIKey *apiKey in [accountStorage.apiKeys allValues])
			if (apiKey.assignedCharacters.count == 0)
				[emptyKeysTmp addObject:apiKey];
		
		if (emptyKeysTmp.count > 0) {
			NSMutableDictionary *section = [NSMutableDictionary dictionaryWithObject:emptyKeysTmp forKey:@"apiKeys"];
			[sectionsTmp addObject:section];
			[queue addOperationWithBlock:^(void) {
				@autoreleasepool {
					[self loadSection:section];
				}
			}];
		}
		
		
		[queue waitUntilAllOperationsAreFinished];
		weakOperation.progress = 0.9;
		[sectionsTmp sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
			EVEAccountStorageCharacter *character1 = [obj1 valueForKey:@"character"];
			EVEAccountStorageCharacter *character2 = [obj2 valueForKey:@"character"];
			if (!character1 && character2)
				return NSOrderedDescending;
			else if (character1 && !character2)
				return NSOrderedAscending;
			else
				return [character1.characterName compare:character2.characterName ? character2.characterName : @""];
		}];
		weakOperation.progress = 1.0;
	}];
	
	[operation setCompletionBlockInCurrentThread:^(void) {
		if (self.loadingOperation == weakOperation)
			self.loadingOperation = nil;
		if (![weakOperation isCancelled])
			self.sections = sectionsTmp;
		[self.tableView reloadData];
	}];
	
	[[EUOperationQueue sharedQueue] addOperation:operation];
}

- (void) didUpdateCloud:(NSNotification*) notification {
	dispatch_async(dispatch_get_main_queue(), ^{
		[self reload];
	});
}

@end
