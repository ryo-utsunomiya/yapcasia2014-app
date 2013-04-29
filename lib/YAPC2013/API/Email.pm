package YAPC2013::API::Email;
use Moo;
use Email::MIME;
use Email::Sender::Simple qw(sendmail);
use Encode ();

sub send_email {
    my ($self, $args) = @_;

    my $email = Email::MIME->create(
        header => [
            From    => $args->{from} || 'no-reply@yapcasia.org',
            To      => $args->{to},
            Subject => Encode::encode('MIME-Header-ISO_2022_JP', $args->{subject}),
            
        ],
        body => Encode::encode('iso-2022-jp', $args->{message}),
        attributes => {
            content_type => 'text/plain',
            charset      => 'iso-2022-jp',
            encoding     => '7bit',
        }
    );

    sendmail($email);
}

no Moo;

1;
