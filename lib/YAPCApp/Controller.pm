package YAPCApp::Controller;
use Mojo::Base 'Mojolicious::Controller';
use Plack::Session;

sub assert_email {
    my $self = shift;
    my $member = $self->assert_logged_in;
    if (! $member) {
        return;
    }

    if ($member->{is_admin}) {
        # I can do whatever the fuck I want
        return $member;
    }

    if (! $member->{email}) {
        $self->redirect_to($self->url_for("/2013/member/email_edit"));
        return;
    }
    return $member;
}


sub assert_logged_in {
    my $self = shift;
    my $member = $self->get_member;
    if (! $member) {
        $self->sessions->set("after_login" => $self->req->url);
        $self->redirect_to($self->url_for("/2013/login"));
        return;
    }

    $self->stash( member => $member );
    return $member;
}

sub assert_admin {
    my $self = shift;
    my $member = $self->assert_logged_in();
    if (! $member) {
        return;
    }

    if ($member->{is_admin}) {
        return $member;
    }

    $self->render_text("No auth (admin)");
    return;
}

1;
