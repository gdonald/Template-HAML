use lib 'lib';
use BDD::Behave;
use Template::HAML;

my $LT = chr(60);
my $GT = chr(62);

sub render(Str $src) { HAML.render(:$src) }

describe 'HAML trim rendering', {
  it 'trim-outer on lone tag strips trailing newline', {
    expect(render("%p$GT hi\n")).to.eq("<p>hi</p>");
  }

  it 'trim-outer eats whitespace surrounding the tag', {
    expect(render("%p first\n%p$GT middle\n%p last\n"))
      .to.eq("<p>first</p><p>middle</p><p>last</p>\n");
  }

  it 'trim-outer on void element', {
    expect(render("%img\n%img$GT\n%img\n")).to.eq("<img><img><img>\n");
  }

  it 'trim-outer on only child of parent', {
    expect(render("%div\n  %p$GT hi\n")).to.eq("<div><p>hi</p></div>\n");
  }

  it 'trim-outer on middle child eats surrounding whitespace', {
    expect(render("%div\n  %a one\n  %b$GT two\n  %c three\n"))
      .to.eq("<div>\n  <a>one</a><b>two</b><c>three</c>\n</div>\n");
  }

  it 'trim-inner with only inline content unchanged', {
    expect(render("%p$LT hi\n")).to.eq("<p>hi</p>\n");
  }

  it 'trim-inner removes whitespace inside the tag', {
    expect(render("%blockquote$LT\n  %div\n    Foo!\n"))
      .to.eq("<blockquote><div>\n  Foo!\n</div></blockquote>\n");
  }

  it 'trim-inner with content and child renders inline', {
    expect(render("%p$LT hello\n  %strong world\n"))
      .to.eq("<p>hello<strong>world</strong></p>\n");
  }

  it 'trim-inner+trim-outer combined (<>) on lone tag', {
    expect(render("%p$LT$GT hi\n")).to.eq("<p>hi</p>");
  }

  it 'trim-outer+trim-inner combined (><)', {
    expect(render("%p$GT$LT\n  %a hi\n")).to.eq("<p><a>hi</a></p>");
  }

  it 'combined trims as only child of parent', {
    expect(render("%div\n  %p$LT$GT\n    %a hi\n"))
      .to.eq("<div><p><a>hi</a></p></div>\n");
  }

  it 'trim-outer on empty tag', {
    expect(render("%p$GT\n")).to.eq("<p></p>");
  }

  it 'consecutive trim-outer tags', {
    expect(render("%a$GT one\n%b$GT two\n")).to.eq("<a>one</a><b>two</b>");
  }

  it 'trim-outer on last child eats trailing newline and parent indent', {
    expect(render("%div\n  %a hi\n  %b$GT bye\n"))
      .to.eq("<div>\n  <a>hi</a><b>bye</b></div>\n");
  }
}
