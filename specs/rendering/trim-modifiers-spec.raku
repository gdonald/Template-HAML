use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Actions;
use Template::HAML::Grammar;
use Template::HAML::Node;

my $LT = chr(60);
my $GT = chr(62);

sub parse-tag(Str $src) {
  my $tree = Node.new;
  $tree.add-child(Node.new);
  my $actions = Actions.new(:$tree);
  Grammar.parse($src, :$actions);
  $tree.children.first(*.object).object;
}

describe 'tag trim modifiers', {
  it 'sets outer trim flag on %p>', {
    my $tag = parse-tag("%p$GT\n");
    expect($tag.trim-outer).to.be-truthy;
    expect($tag.trim-inner).to.be-falsy;
  }

  it 'sets inner trim flag on %p<', {
    my $tag = parse-tag("%p$LT\n");
    expect($tag.trim-inner).to.be-truthy;
    expect($tag.trim-outer).to.be-falsy;
  }

  it 'sets both trims on %p<>', {
    my $tag = parse-tag("%p$LT$GT\n");
    expect($tag.trim-inner).to.be-truthy;
    expect($tag.trim-outer).to.be-truthy;
  }

  it 'sets both trims on %p><', {
    my $tag = parse-tag("%p$GT$LT\n");
    expect($tag.trim-inner).to.be-truthy;
    expect($tag.trim-outer).to.be-truthy;
  }

  it 'sets no trims on plain %p', {
    my $tag = parse-tag("%p\n");
    expect($tag.trim-inner).to.be-falsy;
    expect($tag.trim-outer).to.be-falsy;
  }
}
