use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Multiline;
use Template::HAML::X;

describe 'multi-line expression continuation', {
  it 'joins an array literal split by trailing commas', {
    my $src = q:to/HAML/;
    = [1,
       2,
       3].sum
    HAML
    expect(HAML.render(:$src)).to.eq("6\n");
  }

  it 'joins a paren list split by trailing commas', {
    my $src = q:to/HAML/;
    = (1,
       2,
       3).join('-')
    HAML
    expect(HAML.render(:$src)).to.eq("1-2-3\n");
  }

  it 'joins a multi-line argument list inside parens', {
    my $src = q:to/HAML/;
    = sprintf('%d-%d',
              10, 20)
    HAML
    expect(HAML.render(:$src)).to.eq("10-20\n");
  }

  it 'joins a square-bracket continuation', {
    my $src = q:to/HAML/;
    = [10,
       20,
       30
      ].elems
    HAML
    expect(HAML.render(:$src)).to.eq("3\n");
  }

  it 'joins a curly-brace continuation', {
    my $src = q:to/HAML/;
    = ({
        x => 'y'
      })<x>
    HAML
    expect(HAML.render(:$src)).to.eq("y\n");
  }

  it 'joins nested brackets across multiple lines', {
    my $src = q:to/HAML/;
    = [
        [1, 2],
        [3, 4]
      ].elems
    HAML
    expect(HAML.render(:$src)).to.eq("2\n");
  }

  it 'raises X::HAML::UnbalancedExpression on an unbalanced bracket at EOF', {
    my $src = q:to/HAML/;
    = [1,
    HAML
    expect({ HAML.render(:$src) }).to.raise-error(X::HAML::UnbalancedExpression);
  }

  it 'raises X::HAML::UnbalancedExpression on a trailing comma at EOF', {
    my $src = "= 1,\n";
    expect({ HAML.render(:$src) }).to.raise-error(X::HAML::UnbalancedExpression);
  }

  it 'does not continue on a comma inside a single-quoted string', {
    expect(HAML.render(:src("= 'hello, world'\n"))).to.eq("hello, world\n");
  }

  it 'does not continue on a comma inside a double-quoted string', {
    expect(HAML.render(:src("= \"a, b, c\"\n"))).to.eq("a, b, c\n");
  }

  it 'does not continue on a bracket inside a string', {
    expect(HAML.render(:src("= '[unbalanced'\n"))).to.eq("[unbalanced\n");
  }

  it 'supports != continuation for raw HTML', {
    my $src = q:to/HAML/;
    != ['<b>',
        'hi',
        '</b>'].join('')
    HAML
    expect(HAML.render(:$src)).to.eq("<b>hi</b>\n");
  }

  it 'supports &= continuation with HTML escaping', {
    my $src = q:to/HAML/;
    &= ['<b>',
        'x'].join(',')
    HAML
    expect(HAML.render(:$src)).to.eq("&lt;b&gt;,x\n");
  }

  it 'allows continuation inside an indented block', {
    my $src = q:to/HAML/;
    - if True
      = [1,
         2,
         3].sum
    HAML
    expect(HAML.render(:$src)).to.eq("6\n");
  }

  it 'still parses tags after a joined statement', {
    my $src = q:to/HAML/;
    = [1,
       2,
       3].sum
    %p hi
    HAML
    expect(HAML.render(:$src)).to.eq("6\n<p>hi</p>\n");
  }

  it 'does not join filter body lines that look like statements', {
    my $src = q:to/HAML/;
    :plain
      - this is opaque,
      not a statement
    %p done
    HAML
    expect(HAML.render(:$src))
      .to.eq("- this is opaque,\nnot a statement\n<p>done</p>\n");
  }

  context 'code-state helper', {
    it 'tracks unbalanced paren depth and trailing comma', {
      my %s = Template::HAML::Multiline::code-state("foo(1, 2,");
      expect(%s<bracket-depth>).to.be(1);
      expect(%s<ends-with-comma>).to.be-truthy;
    }

    it 'ignores commas inside strings', {
      my %s = Template::HAML::Multiline::code-state("'hello, world'");
      expect(%s<bracket-depth>).to.be(0);
      expect(%s<ends-with-comma>).to.be-falsy;
    }
  }
}
