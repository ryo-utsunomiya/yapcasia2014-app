package YAPCApp::Controller::Notices;
use Mojo::Base 'YAPCApp::Controller';
use Email::Valid::Loose;

sub subscribe {
    my ($self) = @_;

    if ($self->req->method eq 'POST') {
        # XXX add validation, check for email duplicates
        # grab email
        my $email = $self->req->param('email');
        if (! Email::Valid::Loose->address($email)) {
            $self->stash(invalid_email => 1);
            return;
        }

        # we haven't validated this email yet, so we can't register it
        # for real. insert into notices_subscription_temp
        my $subscription = $self->get('API::NoticesSubscriptionTemp')->create({
            email      => $email,
            code       => $self->get('UUID')->create_str(),
            expires_on => \'DATE_ADD(NOW(), INTERVAL 7 DAY)'
        });
        $self->stash(subscription => $subscription);

        my $message;
        {
            local $self->stash->{format} = "eml";
            $message = $self->render_partial("notices/thankyou");
        }

        $self->get('API::Email')->send_email({
            to      => $email,
            subject => "Thank You For Registering to YAPC::Asia Tokyo 2013 Notices",
            message => $message->to_string,
        });

        $self->stash(email_sent_message => 1, template => "notices/confirm");
    }
}

sub confirm {
    my ($self) = @_;

    my $code = $self->req->param('code');
    if ($code) {
        my ($temp) = $self->get('API::NoticesSubscriptionTemp')->search({
            code => $code
        });
        if (! $temp) {
            $self->stash(code_not_found => 1);
        } else {
            $self->get('API::NoticesSubscriptionTemp')->delete($temp->{id});
            # XXX if we're already registered, just go ahead and ignore
            my @registered = $self->get('API::NoticesSubscription')->search({ email => $temp->{email} });
            if (! @registered) {
                $self->get('API::NoticesSubscription')->create({
                    email => $temp->{email},
                });
            }
            $self->redirect_to("/2013/notices/complete");
            return;
        }
    }
}

sub complete {}

sub unsubscribe {
    my ($self) = @_;
}

1;
