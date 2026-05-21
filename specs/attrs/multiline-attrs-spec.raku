use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Actions;
use Template::HAML::Grammar;
use Template::HAML::Node;

describe 'multi-line attribute syntax', {
  it 'splits a hash-style attr list across multiple lines', {
    my $src = q:to/HAML/;
    %a{
      href: '/',
      title: 'home'
    }
    HAML
    expect(HAML.render(:$src)).to.eq("<a href='/' title='home'></a>\n");
  }

  it 'continues a hash-style attr list on the second line', {
    my $src = q:to/HAML/;
    %a{href: '/',
       title: 'home'}
    HAML
    expect(HAML.render(:$src)).to.eq("<a href='/' title='home'></a>\n");
  }

  it 'allows a nested hash to span multiple lines', {
    my $src = q:to/HAML/;
    %a{
      href: '/',
      data: {
        id: 1,
        role: 'main'
      }
    }
    HAML
    expect(HAML.render(:$src)).to.eq("<a href='/' data-id='1' data-role='main'></a>\n");
  }

  it 'allows an array value to span multiple lines', {
    my $src = q:to/HAML/;
    %a{
      class: [
        'foo',
        'bar'
      ]
    }
    HAML
    expect(HAML.render(:$src)).to.eq("<a class='foo bar'></a>\n");
  }

  it 'splits an HTML-style attr list across multiple lines', {
    my $src = q:to/HAML/;
    %a(
      href='/'
      title='home'
    )
    HAML
    expect(HAML.render(:$src)).to.eq("<a href='/' title='home'></a>\n");
  }

  it 'splits rocket pairs across multiple lines', {
    my $src = q:to/HAML/;
    %a{
      'data-id' => 42,
      :title => 'home'
    }
    HAML
    expect(HAML.render(:$src)).to.eq("<a data-id='42' title='home'></a>\n");
  }

  it 'reads tag content after the closing brace on a new line', {
    my $src = q:to/HAML/;
    %a{
      href: '/'
    } hello
    HAML
    expect(HAML.render(:$src)).to.eq("<a href='/'>hello</a>\n");
  }

  it 'parses children after a multi-line attr hash', {
    my $src = q:to/HAML/;
    %ul{
      class: 'list'
    }
      %li one
      %li two
    HAML
    expect(HAML.render(:$src)).to.eq("<ul class='list'>\n  <li>one</li>\n  <li>two</li>\n</ul>\n");
  }

  it 'honors the self-close marker after a multi-line attr hash', {
    my $src = q:to/HAML/;
    %br{
      class: 'spacer'
    }/
    HAML
    expect(HAML.render(:$src)).to.eq("<br class='spacer'>\n");
  }

  it 'combines an HTML-style multi-line list with a hash-style list on the next line', {
    my $src = q:to/HAML/;
    %a(
      href='/'
    ){title: 'home'}
    HAML
    expect(HAML.render(:$src)).to.eq("<a href='/' title='home'></a>\n");
  }

  it 'tolerates a trailing comma in a multi-line hash', {
    my $src = q:to/HAML/;
    %a{
      href: '/',
    }
    HAML
    expect(HAML.render(:$src)).to.eq("<a href='/'></a>\n");
  }

  it 'continues an attr list across three lines', {
    my $src = q:to/HAML/;
    %a{ href: '/',
         title: 'home',
         class: 'foo' }
    HAML
    expect(HAML.render(:$src)).to.eq("<a class='foo' href='/' title='home'></a>\n");
  }

  it 'records source line numbers across a multi-line attr hash', {
    my $src = q:to/HAML/;
    %div{
      class: 'wrap'
    }
      %p hi
    HAML

    my $tree = Node.new;
    $tree.add-child(Node.new);
    my $actions = Actions.new(:$tree);
    Grammar.parse($src, :$actions);
    my $div = $actions.tree.children.first({ .object.defined });
    expect($div.object.line).to.be(1);
    expect($div.children[0].object.line).to.be(4);
  }
}
