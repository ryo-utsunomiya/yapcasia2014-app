package YAPC2013::Controller::Event;
use Mojo::Base 'YAPC2013::Controller::CRUD';

sub index { $_[0]->redirect_to("/2013/event/list") }

# 名称
# 主催者(member)
# 日時
# 時間
# 場所
# 概要

1;