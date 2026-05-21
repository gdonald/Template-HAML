use lib 'lib';
use BDD::Behave;
use Template::HAML;

describe 'inline and block tag content', {
  it 'inline content, no children', {
    expect(HAML.render(:src("%p Hello\n"))).to.eq("<p>Hello</p>\n");
  }

  it 'no content, no children', {
    expect(HAML.render(:src("%p\n"))).to.eq("<p></p>\n");
  }

  it 'block: only children, no inline content', {
    expect(HAML.render(:src("%div\n  %span Inner\n"))).to.eq("<div>\n  <span>Inner</span>\n</div>\n");
  }

  it 'inline content precedes children', {
    expect(HAML.render(:src("%h1 Title\n  %span Sub\n"))).to.eq("<h1>Title\n  <span>Sub</span>\n</h1>\n");
  }

  it 'nested block layout matches', {
    my $src = qq:to/HAML/;
    %html
      %head
        %title Page
      %body
        %p Hi
    HAML

    expect(HAML.render(:src($src))).to.eq(
      "<html>\n  <head>\n    <title>Page</title>\n  </head>\n  <body>\n    <p>Hi</p>\n  </body>\n</html>\n"
    );
  }
}
