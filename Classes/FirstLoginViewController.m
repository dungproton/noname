/* FirstLoginViewController.m
 *
 * Copyright (C) 2011  Belledonne Comunications, Grenoble, France
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or   
 *  (at your option) any later version.                                 
 *                                                                      
 *  This program is distributed in the hope that it will be useful,     
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of      
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the       
 *  GNU General Public License for more details.                
 *                                                                      
 *  You should have received a copy of the GNU General Public License   
 *  along with this program; if not, write to the Free Software         
 *  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */          

#import "LinphoneManager.h"
#import "FirstLoginViewController.h"
#import "LinphoneManager.h"
#import "PhoneMainView.h"
#import "Constants.h"

@implementation FirstLoginViewController

@synthesize loginButton;
@synthesize siteButton;
@synthesize phoneNumber,countryCode,button0,button1,button2,button3,button4,button5,button6,button7,button8,button9,buttonDel,buttonStar;
@synthesize waitView;

#pragma mark - Lifecycle Functions

- (id)init {
    return [super initWithNibName:@"FirstLoginViewController" bundle:[NSBundle mainBundle]];
}

- (void)dealloc {
	[loginButton release];
	[siteButton release];
	[self.phoneNumber release];
    [self.countryCode release];
	[waitView release];
    
    // Remove all observer
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super dealloc];
}


#pragma mark - UICompositeViewDelegate Functions

static UICompositeViewDescription *compositeDescription = nil;

+ (UICompositeViewDescription *)compositeViewDescription {
    if(compositeDescription == nil) {
        compositeDescription = [[UICompositeViewDescription alloc] init:@"FirstLogin" 
                                                                content:@"FirstLoginViewController" 
                                                               stateBar:nil 
                                                        stateBarEnabled:false 
                                                                 tabBar:nil 
                                                          tabBarEnabled:false 
                                                             fullscreen:false
                                                          landscapeMode:false
                                                           portraitMode:true];
    }
    return compositeDescription;
}

#pragma mark - ViewController Functions

- (void)viewWillAppear:(BOOL)animated { 
    [super viewWillAppear:animated];
    // Set observer
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(registrationUpdateEvent:) 
                                                 name:kLinphoneRegistrationUpdate
                                               object:nil];
    
	
	[self.phoneNumber setText:@""];
	[self.countryCode setText:@"+1"];
    
    // Update on show
    const MSList* list = linphone_core_get_proxy_config_list([LinphoneManager getLc]);
    if(list != NULL) {
        LinphoneProxyConfig *config = (LinphoneProxyConfig*) list->data;
        if(config) {
            [self registrationUpdate:linphone_proxy_config_get_state(config)];
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // Remove observer
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:kLinphoneRegistrationUpdate
                                                  object:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
	NSString* siteUrl = [[LinphoneManager instance] lpConfigStringForKey:@"first_login_view_url"];
	if (siteUrl==nil) {
		siteUrl=@"http://www.linphone.org";
	}
	[siteButton setTitle:siteUrl forState:UIControlStateNormal];
    
}

#pragma mark - Event Functions

- (void)registrationUpdateEvent:(NSNotification*)notif {  
    [self registrationUpdate:[[notif.userInfo objectForKey: @"state"] intValue]];
}


#pragma mark - 

- (void)registrationUpdate:(LinphoneRegistrationState)state {
    switch (state) {
        case LinphoneRegistrationOk: {
            [[LinphoneManager instance] lpConfigSetBool:FALSE forKey:@"enable_first_login_view_preference"]; 
            [waitView setHidden:true];
            [[PhoneMainView instance] changeCurrentView:[DialerViewController compositeViewDescription]];
            break;
        }
        case LinphoneRegistrationNone: 
        case LinphoneRegistrationCleared: {
            [waitView setHidden:true];	
            break;
        }
        case LinphoneRegistrationFailed: {
            [waitView setHidden:true];
            
            //erase uername passwd
			[[LinphoneManager instance] lpConfigSetString:nil forKey:@"wizard_username"];
			[[LinphoneManager instance] lpConfigSetString:nil forKey:@"wizard_password"];
            break;
        }
        case LinphoneRegistrationProgress: {
            [waitView setHidden:false];
            break;
        }
        default: break;
    }
}

#pragma mark - Action Functions

- (void)onSiteClick:(id)sender {
    NSURL *url = [NSURL URLWithString:siteButton.titleLabel.text];
    [[UIApplication sharedApplication] openURL:url];
    return;
}

- (void)onLoginClick:(id)sender {
  
	NSString* errorMessage=nil;
	if ([phoneNumber.text length]==0 ) {
		errorMessage=NSLocalizedString(@"Enter your phonenumber",nil);
	}

	if (errorMessage != nil) {
		UIAlertView* error=nil;
		error = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Alert",nil)
										   message:errorMessage 
										  delegate:nil 
								 cancelButtonTitle:NSLocalizedString(@"Continue",nil) 
								 otherButtonTitles:nil];
		[error show];
        [error release];
	} else {
		linphone_core_clear_all_auth_info([LinphoneManager getLc]);
		linphone_core_clear_proxy_config([LinphoneManager getLc]);
		LinphoneProxyConfig* proxyCfg = linphone_core_create_proxy_config([LinphoneManager getLc]);
        
		//default domain is supposed to be preset from linphonerc
        
		NSString* identity = [NSString stringWithFormat:@"sip:%@@%s",phoneNumber.text, linphone_proxy_config_get_addr(proxyCfg)];
		linphone_proxy_config_set_identity(proxyCfg,[identity UTF8String]);
		LinphoneAuthInfo* auth_info =linphone_auth_info_new([phoneNumber.text UTF8String]
															,[phoneNumber.text UTF8String]
															,[PASS_WORD UTF8String]
															,NULL
															,NULL);
         
		linphone_core_add_auth_info([LinphoneManager getLc], auth_info);
		linphone_core_add_proxy_config([LinphoneManager getLc], proxyCfg);
		linphone_core_set_default_proxy([LinphoneManager getLc], proxyCfg);
		[self.waitView setHidden:false];
        [self addProxyConfig:phoneNumber.text password:PASS_WORD domain:PROXY_SERVER server:nil];
        
        [[PhoneMainView instance] changeCurrentView:[DialerViewController compositeViewDescription]];
  	};
   
}

-(IBAction)btnPhoneClick:(id)sender{
    NSString *num = phoneNumber.text;
    if ([sender tag] == 0) {
        num = [num stringByAppendingString:@"0"];
    }
    if ([sender tag] == 1) {
        num = [num stringByAppendingString:@"1"];
    }
    if ([sender tag] == 2) {
        num = [num stringByAppendingString:@"2"];
    }
    if ([sender tag] == 3) {
        num = [num stringByAppendingString:@"3"];
    }
    if ([sender tag] == 4) {
        num = [num stringByAppendingString:@"4"];
    }
    if ([sender tag] == 5) {
        num = [num stringByAppendingString:@"5"];
    }
    if ([sender tag] == 6) {
        num = [num stringByAppendingString:@"6"];
    }
    if ([sender tag] == 7) {
        num = [num stringByAppendingString:@"7"];
    }
    if ([sender tag] == 8) {
        num = [num stringByAppendingString:@"8"];
    }
    if ([sender tag] == 9) {
        num = [num stringByAppendingString:@"9"];
    }
    if ([sender tag] == 11) {
        num = [num stringByAppendingString:@"*"];
    }
    if ([sender tag] == 12) {
        num = [num substringToIndex:(num.length - 1)];
    }
    phoneNumber.text = num;
}

-(BOOL) textFieldShouldBeginEditing:(UITextField *)textField{
    [textField resignFirstResponder];
    return NO;
}

//main function
- (void)setDefaultSettings:(LinphoneProxyConfig*)proxyCfg {
    BOOL pushnotification = [[LinphoneManager instance] lpConfigBoolForKey:@"push_notification" forSection:@"wizard"];
    [[LinphoneManager instance] lpConfigSetBool:pushnotification forKey:@"pushnotification_preference"];
    if(pushnotification) {
        [[LinphoneManager instance] addPushTokenToProxyConfig:proxyCfg];
    }
    int expires = [[LinphoneManager instance] lpConfigIntForKey:@"expires" forSection:@"wizard"];
    linphone_proxy_config_expires(proxyCfg, expires);
    
    NSString* transport = [[LinphoneManager instance] lpConfigStringForKey:@"transport" forSection:@"wizard"];
    LinphoneCore *lc = [LinphoneManager getLc];
    LCSipTransports transportValue={0};
	if (transport!=nil) {
		if (linphone_core_get_sip_transports(lc, &transportValue)) {
			[LinphoneLogger logc:LinphoneLoggerError format:"cannot get current transport"];
		}
		// Only one port can be set at one time, the others's value is 0
		if ([transport isEqualToString:@"tcp"]) {
			transportValue.tcp_port=transportValue.tcp_port|transportValue.udp_port|transportValue.tls_port;
			transportValue.udp_port=0;
            transportValue.tls_port=0;
		} else if ([transport isEqualToString:@"udp"]){
			transportValue.udp_port=transportValue.tcp_port|transportValue.udp_port|transportValue.tls_port;
			transportValue.tcp_port=0;
            transportValue.tls_port=0;
		} else if ([transport isEqualToString:@"tls"]){
			transportValue.tls_port=transportValue.tcp_port|transportValue.udp_port|transportValue.tls_port;
			transportValue.tcp_port=0;
            transportValue.udp_port=0;
		} else {
			[LinphoneLogger logc:LinphoneLoggerError format:"unexpected transport [%s]",[transport cStringUsingEncoding:[NSString defaultCStringEncoding]]];
		}
		if (linphone_core_set_sip_transports(lc, &transportValue)) {
			[LinphoneLogger logc:LinphoneLoggerError format:"cannot set transport"];
		}
	}
    
    NSString* sharing_server = [[LinphoneManager instance] lpConfigStringForKey:@"sharing_server" forSection:@"wizard"];
    [[LinphoneManager instance] lpConfigSetString:sharing_server forKey:@"sharing_server_preference"];
    
    BOOL ice = [[LinphoneManager instance] lpConfigBoolForKey:@"ice" forSection:@"wizard"];
    [[LinphoneManager instance] lpConfigSetBool:ice forKey:@"ice_preference"];
    
    NSString* stun = [[LinphoneManager instance] lpConfigStringForKey:@"stun" forSection:@"wizard"];
    [[LinphoneManager instance] lpConfigSetString:stun forKey:@"stun_preference"];
    
    if ([stun length] > 0){
        linphone_core_set_stun_server(lc, [stun UTF8String]);
        if(ice) {
            linphone_core_set_firewall_policy(lc, LinphonePolicyUseIce);
        } else {
            linphone_core_set_firewall_policy(lc, LinphonePolicyUseStun);
        }
    } else {
        linphone_core_set_stun_server(lc, NULL);
        linphone_core_set_firewall_policy(lc, LinphonePolicyNoFirewall);
    }
}

- (void)addProxyConfig:(NSString*)username password:(NSString*)password domain:(NSString*)domain server:(NSString*)server {
    
    if(server == nil) {
        server = domain;
    }
	LinphoneProxyConfig* proxyCfg = linphone_core_create_proxy_config([LinphoneManager getLc]);
    char normalizedUserName[256];
    [[LinphoneManager instance] lpConfigSetBool:YES forKey:@"ice_preference"];
    [[LinphoneManager instance] lpConfigSetString:STUN_SERVER forKey:@"stun_preference"];
    [[LinphoneManager instance] lpConfigSetString:@"tcp" forKey:@"transport_preference"];
    LinphoneAddress* linphoneAddress = linphone_address_new("sip:user@domain.com");
    linphone_proxy_config_normalize_number(proxyCfg, [username cStringUsingEncoding:[NSString defaultCStringEncoding]], normalizedUserName, sizeof(normalizedUserName));
    linphone_address_set_username(linphoneAddress, normalizedUserName);
    linphone_address_set_domain(linphoneAddress, [domain UTF8String]);
    const char* identity = linphone_address_as_string_uri_only(linphoneAddress);
	LinphoneAuthInfo* info = linphone_auth_info_new([username UTF8String], NULL, [password UTF8String], NULL, NULL);
	linphone_proxy_config_set_identity(proxyCfg, identity);
	linphone_proxy_config_set_server_addr(proxyCfg, [server UTF8String]);
    if([server compare:domain options:NSCaseInsensitiveSearch] != 0) {
        linphone_proxy_config_set_route(proxyCfg, [server UTF8String]);
    }
    int defaultExpire = [[LinphoneManager instance] lpConfigIntForKey:@"default_expires"];
    if (defaultExpire >= 0)
        linphone_proxy_config_expires(proxyCfg, defaultExpire);
    if([domain compare:[[LinphoneManager instance] lpConfigStringForKey:@"domain" forSection:@"wizard"] options:NSCaseInsensitiveSearch] == 0) {
        [self setDefaultSettings:proxyCfg];
    }
    linphone_proxy_config_enable_register(proxyCfg, true);
    linphone_core_add_proxy_config([LinphoneManager getLc], proxyCfg);
	linphone_core_set_default_proxy([LinphoneManager getLc], proxyCfg);
	linphone_core_add_auth_info([LinphoneManager getLc], info);
    LinphoneCore *lc=[LinphoneManager getLc];
    linphone_core_set_stun_server(lc, [STUN_SERVER UTF8String]);
    linphone_core_set_firewall_policy(lc, LinphonePolicyUseIce);
    
    LCSipTransports transportValue={0};
    NSString *transport = @"tcp";
    int port_preference = 5060;
    
    
    //lp_config_set_int(linphone_core_get_config(lc),"sip","sip_random_port", random_port_preference);
	//lp_config_set_int(linphone_core_get_config(lc),"sip","sip_tcp_random_port", random_port_preference);
    //lp_config_set_int(linphone_core_get_config(lc),"sip","sip_tls_random_port", random_port_preference);
    //if(random_port_preference) {
    port_preference = (0xDFFF&random())+1024;
    [[LinphoneManager instance] lpConfigSetInt:port_preference forKey:@"port_preference"];
    //    [self setInteger:port_preference forKey:@"port_preference"]; // Update back preference
    //}
	if (transport!=nil) {
		if (linphone_core_get_sip_transports(lc, &transportValue)) {
			[LinphoneLogger logc:LinphoneLoggerError format:"cannot get current transport"];
		}
		// Only one port can be set at one time, the others's value is 0
		if ([transport isEqualToString:@"tcp"]) {
			transportValue.tcp_port=port_preference;
			transportValue.udp_port=0;
            transportValue.tls_port=0;
		} else if ([transport isEqualToString:@"udp"]){
			transportValue.udp_port=port_preference;
			transportValue.tcp_port=0;
            transportValue.tls_port=0;
		} else if ([transport isEqualToString:@"tls"]){
			transportValue.tls_port=port_preference;
			transportValue.tcp_port=0;
            transportValue.udp_port=0;
		} else {
			[LinphoneLogger logc:LinphoneLoggerError format:"unexpected transport [%s]",[transport cStringUsingEncoding:[NSString defaultCStringEncoding]]];
		}
		if (linphone_core_set_sip_transports(lc, &transportValue)) {
			[LinphoneLogger logc:LinphoneLoggerError format:"cannot set transport"];
		}
	}
}

#pragma mark - UITextFieldDelegate Functions

- (BOOL)textFieldShouldReturn:(UITextField *)theTextField {
    // When the user presses return, take focus away from the text field so that the keyboard is dismissed.
    [theTextField resignFirstResponder];
    return YES;
}

@end
