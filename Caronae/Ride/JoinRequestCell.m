#import "JoinRequestCell.h"
#import "UIImageView+crn_setImageWithURL.h"
#import "Caronae-Swift.h"

@implementation JoinRequestCell

- (void)awakeFromNib {
    [super awakeFromNib];
    UITapGestureRecognizer *pictureTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapUserDetails:)];
    pictureTap.numberOfTapsRequired = 1;
    [_userPhoto addGestureRecognizer:pictureTap];
    
    UITapGestureRecognizer *nameTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapUserDetails:)];
    nameTap.numberOfTapsRequired = 1;
    [_userName addGestureRecognizer:nameTap];
}

- (void)configureCellWithUser:(User *)user {
    _requestingUser = user;
    _userName.text = user.name;
    _userCourse.text = user.course.length > 0 ? [NSString stringWithFormat:@"%@ | %@", user.profile, user.course] : user.profile;
    
    if (user.profilePictureURL.length > 0) {
        [self.userPhoto crn_setImageWithURL:[NSURL URLWithString:user.profilePictureURL]];
    }
}

- (void)setColor:(UIColor *)color {
    _color = color;
    [_acceptButton setTitleColor:color forState:UIControlStateNormal];
    _acceptButton.layer.borderColor = color.CGColor;
    _userPhoto.layer.borderColor = color.CGColor;
    self.tintColor = color;
}

- (void)setButtonsEnabled:(BOOL)enabled {
    _acceptButton.enabled = enabled;
    _declineButton.enabled = enabled;
    if (enabled) {
        _acceptButton.alpha = 1.0f;
        _declineButton.alpha = 1.0f;
    }
    else {
        _acceptButton.alpha = 0.5f;
        _declineButton.alpha = 0.5f;
    }
}


#pragma mark - IBActions

- (IBAction)didTapAcceptButton:(id)sender {
    [self.delegate joinRequest:self.requestingUser hasAccepted:YES cell:self];
}

- (IBAction)didTapDeclineButton:(id)sender {
    [self.delegate joinRequest:self.requestingUser hasAccepted:NO cell:self];
}

- (IBAction)didTapUserDetails:(id)sender {
    [self.delegate tappedUserDetailsForRequest:self.requestingUser];
}

@end
