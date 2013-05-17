package YAPC2013::Controller::Member;

use Mojo::Base 'YAPC2013::Controller::CRUD';
use Data::Dumper;
use Data::Recursive::Encode;

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

sub email_confirm {
    my $self = shift;
    $self->assert_logged_in() or return;

    my $member = $self->get_member;
    my $email = $self->req->param('email');
    my $fv = $self->get('FormValidator');
    my $params = $self->req->params->to_hash;
    my $results = $fv->check( { %$params }, 'email.check' );

    $self->render( member => $member, email => $email, invalid => $results->{invalid} );
}

sub email_submit {
    my $self = shift;
    warn 'email_submit';
    $self->assert_logged_in() or return;

    #TODO validation
    my $email = $self->req->param('email');

    #regist email
    my $member = $self->get_member;
    warn Dumper $self->get('API::Member')->update( $member->{id}, {
        email => $email,
    });
warn Dumper $self->get('API::Member')->lookup( $member->{id} );
    $self->sessions->set(member => $self->get('API::Member')->lookup( $member->{id} ));

warn Dumper $self->sessions->get('member');

    my $content = $self->render("member/email_confirm.eml", partial => 1);

    #email send
    $self->get('API::Email')->send_email({
        from    => 'yapc@perlassociation.org',
        to      => $email,
        subject => 'YAPC::Asia Tokyo 2013 Email Confirmation',
        message => $content,
    });

    $self->render("member/email_submit", email => $email );
}

1;
