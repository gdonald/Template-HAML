use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Helpers;

describe 'HAML tab-up/tab-down', {
  it 'tab-up bumps indent until tab-down restores it', {
    my $src = q:to/HAML/;
    %div
      - tab-up
      %p deep
      - tab-down
      %p back
    HAML
    expect(HAML.render(:$src))
      .to.eq("<div>\n    <p>deep</p>\n  <p>back</p>\n</div>\n");
  }

  it 'tab-up 2 bumps two levels', {
    my $src = q:to/HAML/;
    %div
      - tab-up 2
      %p deep
      - tab-down 2
      %p back
    HAML
    expect(HAML.render(:$src))
      .to.eq("<div>\n      <p>deep</p>\n  <p>back</p>\n</div>\n");
  }

  it 'tab-up bumps indent for `=` output', {
    my $src = q:to/HAML/;
    %div
      - tab-up
      = haml-concat('x')
      - tab-down
    HAML
    expect(HAML.render(:$src)).to.eq("<div>\n    x\n</div>\n");
  }

  it 'tab offset resets between renders', {
    my $src = q:to/HAML/;
    %div
      - tab-up
      %p deep
    HAML
    HAML.render(:$src);
    expect(HAML.render(:src("%p hi\n"))).to.eq("<p>hi</p>\n");
  }

  it 'tab-up/tab-down outside render is a no-op', {
    expect({ tab-up(); tab-down() }).to.not.raise-error;
  }

  it 'tab-up bumps plain text indent', {
    my $src = q:to/HAML/;
    %div
      - tab-up
      hello
      - tab-down
    HAML
    expect(HAML.render(:$src)).to.eq("<div>\n    hello\n</div>\n");
  }
}
