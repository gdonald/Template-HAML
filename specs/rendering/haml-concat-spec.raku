use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Helpers;

describe 'haml-concat', {
  it '= haml-concat emits unescaped value', {
    my $r = HAML.render(:src(q:to/HAML/));
    = haml-concat('<b>x</b>')
    HAML
    expect($r).to.eq("<b>x</b>\n");
  }

  it '- haml-concat emits buffered content from silent statements', {
    my $r = HAML.render(:src(q:to/HAML/));
    - haml-concat('one')
    - haml-concat('two')
    HAML
    expect($r).to.eq("one\ntwo\n");
  }

  it 'multiple haml-concat calls accumulate in one statement', {
    my $r = HAML.render(:src(q:to/HAML/));
    - haml-concat('a'); haml-concat('b'); haml-concat('c')
    HAML
    expect($r).to.eq("abc\n");
  }

  it 'buffer flushes before return value on `=`', {
    my $r = HAML.render(:src(q:to/HAML/));
    = do { haml-concat('pre-'); 'ret' }
    HAML
    expect($r).to.eq("pre-ret\n");
  }

  it 'haml-concat return is SafeString (no escape)', {
    my $r = HAML.render(:src(q:to/HAML/));
    = haml-concat('<&>')
    HAML
    expect($r).to.eq("<&>\n");
  }

  it 'haml-concat inside a tag indents output', {
    my $r = HAML.render(:src(q:to/HAML/));
    %p
      = haml-concat('hi')
    HAML
    expect($r).to.eq("<p>\n  hi\n</p>\n");
  }

  it 'haml-concat outside eval returns SafeString', {
    my $ss = haml-concat('<a>');
    expect($ss).to.be-a(Template::HAML::Helpers::SafeString);
  }
}
