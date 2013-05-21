package YAPC2013::Controller::Member;

use Mojo::Base 'YAPC2013::Controller::CRUD';
use Data::Dumper;
use Data::Recursive::Encode;
use Email::Valid::Loose;

sub index {
    my $self = shift;
    my $member = $self->assert_logged_in or return;
    $self->redirect_to("/2013/member/show/$member->{id}");
}

sub show {
    my $self = shift;

    my $object_id = $self->match->captures->{object_id};
    my $object = $self->load_object( $object_id );

    if (! $object) {
        $self->render_not_found();
        return;
    }

    if (my $member = $self->get_member) {
        if ($object_id eq $member->{id}) {
            $self->stash( owner => 1 );
        }
    }

    my $talks = $self->get('API::Talk')->search({
        member_id => $object->{id}
    });

    $self->stash( talks => $talks );
    $self->SUPER::show();
}

sub email_edit {
    my $self = shift;
    $self->assert_logged_in() or return;

    my $member = $self->get_member;
    $self->render( member => $member );
}

sub email_submit {
    my $self = shift;
    warn 'email_submit';
    $self->assert_logged_in() or return;

    my $member = $self->get_member;
    $self->stash(member => $member);

    my $email = $self->req->param('email');
warn $email;
    if (! Email::Valid::Loose->address($email) || $member->{email} eq $email ) {
        $self->stash( invalid_email => 1, email => $email );
        $self->render("member/email_edit");
        return;
    }

    my $subscription = $self->get('API::MemberTemp')->create({
        member_id  => $member->{id},
        email      => $email,
        code       => $self->get('UUID')->create_str(),
        expires_on => \'DATE_ADD(NOW(), INTERVAL 7 DAY)'
    });
    $self->stash(subscription => $subscription);

    my $message = $self->render("member/email_confirm", format => "eml", partial => 1);

    #email send
    $self->get('API::Email')->send_email({
        from    => 'yapc@perlassociation.org',
        to      => $email,
        subject => 'YAPC::Asia Tokyo 2013 Email Confirmation',
        message => $message,
    });

    $self->render("member/confirm", format => "html", email => $email, email_sent_message => 1 );
}

sub confirm {
    my $self = shift;
    my $code = $self->req->param('code');
    if ($code) {
        my $member = $self->get_member;
        my ($temp) = $self->get('API::MemberTemp')->search({
            member_id => $member->{id},
            code => $code
        });
        if (! $temp) {
            $self->stash(code_not_found => 1);
        } else {
            my $email = $temp->{email};
            $self->get('API::MemberTemp')->delete($temp->{id});
            $self->get('API::Member')->update( $member->{id}, { email => $email } );
            $self->sessions->set(member => $self->get('API::Member')->lookup( $member->{id} ));
            $self->redirect_to("/2013/member/complete");
            return;
        }
    }
}

1;
