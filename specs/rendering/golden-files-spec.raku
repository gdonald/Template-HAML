use lib 'lib';
use BDD::Behave;
use Template::HAML;

my $dir = 't/fixtures/golden'.IO;
my @pairs = $dir.dir(:test(/\.haml$/)).sort(*.Str);

describe 'golden fixtures', {
  for @pairs -> $haml-file {
    my $name = $haml-file.basename.subst(/\.haml$/, '');
    my $html-file = $dir.add("$name.html");

    it "renders $name", {
      expect($html-file.e).to.be-truthy;
      my $src      = $haml-file.slurp;
      my $expected = $html-file.slurp;
      expect(HAML.render(:$src)).to.eq($expected);
    }
  }
}
