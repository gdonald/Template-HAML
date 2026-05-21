use lib 'lib';
use BDD::Behave;
use Template::HAML;

describe 'HAML repeat', {
  it '`- repeat 3` renders children three times', {
    my $src = qq:to/HAML/;
    %ul
      - repeat 3
        %li hi
    HAML
    expect(HAML.render(:$src))
      .to.eq("<ul>\n  <li>hi</li>\n  <li>hi</li>\n  <li>hi</li>\n</ul>\n");
  }

  it '`- repeat 0` renders nothing', {
    my $src = qq:to/HAML/;
    %ul
      - repeat 0
        %li hi
    HAML
    expect(HAML.render(:$src)).to.eq("<ul>\n</ul>\n");
  }

  it 'negative count renders nothing', {
    my $src = qq:to/HAML/;
    %ul
      - repeat -2
        %li hi
    HAML
    expect(HAML.render(:$src)).to.eq("<ul>\n</ul>\n");
  }

  it 'count comes from a local', {
    my $src = qq:to/HAML/;
    %ul
      - repeat \$n
        %li hi
    HAML
    expect(HAML.render(:$src, :locals(%(n => 2))))
      .to.eq("<ul>\n  <li>hi</li>\n  <li>hi</li>\n</ul>\n");
  }

  it 'repeat at top level', {
    my $src = qq:to/HAML/;
    - repeat 2
      %p x
    HAML
    expect(HAML.render(:$src)).to.eq("<p>x</p>\n<p>x</p>\n");
  }
}
