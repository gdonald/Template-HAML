use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Actions;
use Template::HAML::Grammar;
use Template::HAML::Node;
use Template::HAML::X;

sub fresh-actions(--> Actions) {
  my $tree = Node.new;
  $tree.add-child(Node.new);
  Actions.new(:$tree);
}

describe 'Grammar rules', {
  context 'sigil', {
    it 'parses %', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('%', :rule<sigil>, :$actions);
      expect($m.Str).to.be('%');
    }

    it 'parses .', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('.', :rule<sigil>, :$actions);
      expect($m.Str).to.be('.');
    }

    it 'parses #', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('#', :rule<sigil>, :$actions);
      expect($m.Str).to.be('#');
    }
  }

  context 'output-op', {
    it 'parses =', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('=', :rule<output-op>, :$actions);
      expect($m.Str).to.be('=');
    }

    it 'parses -', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('-', :rule<output-op>, :$actions);
      expect($m.Str).to.be('-');
    }

    it 'parses !=', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('!=', :rule<output-op>, :$actions);
      expect($m.Str).to.be('!=');
    }

    it 'parses &=', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('&=', :rule<output-op>, :$actions);
      expect($m.Str).to.be('&=');
    }
  }

  context 'param-key', {
    it 'parses foo:', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('foo:', :rule<param-key>, :$actions);
      expect($m.made).to.be('foo');
    }
  }

  context 'quoted-string', {
    it 'parses "foo"', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('"foo"', :rule<quoted-string>, :$actions);
      expect($m.made).to.be('foo');
    }

    it 'parses "foo bar"', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('"foo bar"', :rule<quoted-string>, :$actions);
      expect($m.made).to.be('foo bar');
    }

    it "parses 'foo'", {
      my $actions = fresh-actions;
      my $m = Grammar.parse("'foo'", :rule<quoted-string>, :$actions);
      expect($m.made).to.be('foo');
    }

    it "parses 'foo bar'", {
      my $actions = fresh-actions;
      my $m = Grammar.parse("'foo bar'", :rule<quoted-string>, :$actions);
      expect($m.made).to.be('foo bar');
    }
  }

  context 'param-value', {
    it 'parses "foo"', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('"foo"', :rule<param-value>, :$actions);
      expect($m.made).to.be('foo');
    }

    it 'parses "foo bar"', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('"foo bar"', :rule<param-value>, :$actions);
      expect($m.made).to.be('foo bar');
    }

    it "parses 'foo'", {
      my $actions = fresh-actions;
      my $m = Grammar.parse("'foo'", :rule<param-value>, :$actions);
      expect($m.made).to.be('foo');
    }

    it "parses 'foo bar'", {
      my $actions = fresh-actions;
      my $m = Grammar.parse("'foo bar'", :rule<param-value>, :$actions);
      expect($m.made).to.be('foo bar');
    }

    it 'parses :foo', {
      my $actions = fresh-actions;
      my $m = Grammar.parse(':foo', :rule<param-value>, :$actions);
      expect($m.made).to.be('foo');
    }
  }

  context 'param', {
    it 'parses class: "foo" as a Pair', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('class: "foo"', :rule<param>, :$actions);
      expect($m.made).to.be-a(Pair);
      expect($m.made<class>).to.be('foo');
    }

    it "parses class: 'foo' as a Pair", {
      my $actions = fresh-actions;
      my $m = Grammar.parse("class: 'foo'", :rule<param>, :$actions);
      expect($m.made).to.be-a(Pair);
      expect($m.made<class>).to.be('foo');
    }

    it 'parses class: "foo bar" as a Pair', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('class: "foo bar"', :rule<param>, :$actions);
      expect($m.made).to.be-a(Pair);
      expect($m.made<class>).to.be('foo bar');
    }

    it "parses class: 'foo bar' as a Pair", {
      my $actions = fresh-actions;
      my $m = Grammar.parse("class: 'foo bar'", :rule<param>, :$actions);
      expect($m.made).to.be-a(Pair);
      expect($m.made<class>).to.be('foo bar');
    }

    it 'parses class: :foo as a Pair', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('class: :foo', :rule<param>, :$actions);
      expect($m.made).to.be-a(Pair);
      expect($m.made<class>).to.be('foo');
    }
  }

  context 'params', {
    it 'parses class: "foo" as a Hash', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('class: "foo"', :rule<params>, :$actions);
      expect($m.made).to.be-a(Hash);
      expect($m.made<class>).to.be('foo');
    }

    it "parses class: 'foo' as a Hash", {
      my $actions = fresh-actions;
      my $m = Grammar.parse("class: 'foo'", :rule<params>, :$actions);
      expect($m.made).to.be-a(Hash);
      expect($m.made<class>).to.be('foo');
    }

    it 'parses class: "foo bar" as a Hash', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('class: "foo bar"', :rule<params>, :$actions);
      expect($m.made).to.be-a(Hash);
      expect($m.made<class>).to.be('foo bar');
    }

    it "parses class: 'foo bar' as a Hash", {
      my $actions = fresh-actions;
      my $m = Grammar.parse("class: 'foo bar'", :rule<params>, :$actions);
      expect($m.made).to.be-a(Hash);
      expect($m.made<class>).to.be('foo bar');
    }

    it 'parses class: :foo as a Hash', {
      my $actions = fresh-actions;
      my $m = Grammar.parse("class: :foo", :rule<params>, :$actions);
      expect($m.made).to.be-a(Hash);
      expect($m.made<class>).to.be('foo');
    }

    it 'parses class + id with double then single quotes', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('class: "foo", id: \'foo_1\'', :rule<params>, :$actions);
      expect($m.made).to.be-a(Hash);
      expect($m.made<class>).to.be('foo');
      expect($m.made<id>).to.be('foo_1');
    }

    it 'parses class + id with mixed quotes', {
      my $actions = fresh-actions;
      my $m = Grammar.parse("class: \"foo\", id: 'foo_1'", :rule<params>, :$actions);
      expect($m.made).to.be-a(Hash);
      expect($m.made<class>).to.be('foo');
      expect($m.made<id>).to.be('foo_1');
    }

    it 'parses class + id + style with colon-prefixed value', {
      my $actions = fresh-actions;
      my $m = Grammar.parse("class: :foo, id: 'foo_1', style: 'bar'", :rule<params>, :$actions);
      expect($m.made).to.be-a(Hash);
      expect($m.made<class>).to.be('foo');
      expect($m.made<id>).to.be('foo_1');
      expect($m.made<style>).to.be('bar');
    }
  }

  context 'params-hash', {
    it 'parses { class: :foo, id: \'foo_1\', style: \'bar\' }', {
      my $actions = fresh-actions;
      my $m = Grammar.parse("\{ class: :foo, id: 'foo_1', style: 'bar' \}", :rule<params-hash>, :$actions);
      my %h = $m.made.list.map({ .key => .value });
      expect(%h).to.be-a(Hash);
      expect(%h<class>).to.be('foo');
      expect(%h<id>).to.be('foo_1');
      expect(%h<style>).to.be('bar');
    }

    it 'parses { class: :foo, id: "foo_1", style: "bar" }', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('{ class: :foo, id: "foo_1", style: "bar" }', :rule<params-hash>, :$actions);
      my %h = $m.made.list.map({ .key => .value });
      expect(%h).to.be-a(Hash);
      expect(%h<class>).to.be('foo');
      expect(%h<id>).to.be('foo_1');
      expect(%h<style>).to.be('bar');
    }
  }

  context 'indent', {
    it 'counts two spaces', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('  ', :rule<indent>, :$actions);
      expect($m.made).to.be(2);
    }

    it 'counts four spaces', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('    ', :rule<indent>, :$actions);
      expect($m.made).to.be(4);
    }

    it 'raises X::HAML::IndentMixed when tabs and spaces are mixed', {
      expect({ HAML.render(:src("\t %h1 hi\n")) }).to.raise-error(X::HAML::IndentMixed);
    }

    it 'raises X::HAML::IndentInconsistent on a non-multiple indent', {
      expect({ HAML.render(:src("%h1\n  %p\n   %x\n")) }).to.raise-error(X::HAML::IndentInconsistent);
    }
  }

  context 'css-class', {
    it 'parses .foo', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('.foo', :rule<css-class>, :$actions);
      expect($m.made).to.be('foo');
    }
  }

  context 'css-classes', {
    it 'parses .foo.bar', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('.foo.bar', :rule<css-classes>, :$actions);
      my $classes = <foo bar>;
      expect($m.made.elems).to.be(2);
      expect(?$classes.grep($m.made[0])).to.be-truthy;
      expect(?$classes.grep($m.made[1])).to.be-truthy;
    }

    it 'parses .foo.bar.baz', {
      my $actions = fresh-actions;
      my $m = Grammar.parse('.foo.bar.baz', :rule<css-classes>, :$actions);
      my $classes = <foo bar baz>;
      expect($m.made.elems).to.be(3);
      expect(?$classes.grep($m.made[0])).to.be-truthy;
      expect(?$classes.grep($m.made[1])).to.be-truthy;
      expect(?$classes.grep($m.made[2])).to.be-truthy;
    }
  }
}
