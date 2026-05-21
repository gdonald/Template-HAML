use lib 'lib';
use BDD::Behave;
use Template::HAML;

describe 'HAML.render', {
  it 'renders simple nested tags with class shorthand', {
    my $src = qq:to/HAML/;
    %section.container
      %h1 Title
      %h2 Subtitle
    HAML

    my $expected = qq:to/HTML/;
    <section class='container'>
      <h1>Title</h1>
      <h2>Subtitle</h2>
    </section>
    HTML

    expect(HAML.render(:$src)).to.eq($expected);
  }

  it 'renders a nested html document tree', {
    my $src = qq:to/HAML/;
    %html
      %head
        %title Page Title
      %body
        %section.container
          %h1 Title
          %h2 Subtitle
          %p Content
          %ul
            %li Foo
            %li Bar
        %section.container
          %div More
    HAML

    my $expected = qq:to/HTML/;
    <html>
      <head>
        <title>Page Title</title>
      </head>
      <body>
        <section class='container'>
          <h1>Title</h1>
          <h2>Subtitle</h2>
          <p>Content</p>
          <ul>
            <li>Foo</li>
            <li>Bar</li>
          </ul>
        </section>
        <section class='container'>
          <div>More</div>
        </section>
      </body>
    </html>
    HTML

    expect(HAML.render(:$src)).to.eq($expected);
  }
}
