use lib 'lib';
use BDD::Behave;
use Template::HAML;

class Deal {
  method id { 7 }
}

describe 'an interpolated attribute value', {
  context 'at the top level of a template', {
    let(:html, {
      HAML.render(
        :src(q:to/HAML/),
          %a{href: "/deals/#{$deal.id}"} x
          HAML
        :locals(%( deal => Deal.new )),
      )
    });

    it 'reads a local passed to the template', {
      expect(html).to.include("href='/deals/7'");
    }
  }

  context 'inside a for loop body', {
    let(:html, {
      HAML.render(
        :src(q:to/HAML/),
          - for $items -> $item
            %a{href: "/deals/#{$deal.id}/#{$item}"}= $item
          HAML
        :locals(%( items => <a b>, deal => Deal.new )),
      )
    });

    it 'reads a local passed to the template', {
      expect(html).to.include("href='/deals/7/a'");
    }
  }

  context 'inside a for loop body when the template also reads the local outside the loop', {
    let(:html, {
      HAML.render(
        :src(q:to/HAML/),
          %h1= $deal.id
          - for $items -> $item
            %a{href: "/deals/#{$deal.id}/#{$item}"}= $item
          HAML
        :locals(%( items => <a b>, deal => Deal.new )),
      )
    });

    it 'reads a local passed to the template', {
      expect(html).to.include("href='/deals/7/b'");
    }
  }

  context 'inside nested for loop bodies', {
    let(:html, {
      HAML.render(
        :src(q:to/HAML/),
          - for $groups -> $group
            - for $items -> $item
              %a{href: "/deals/#{$deal.id}/#{$group}/#{$item}"}= $item
          HAML
        :locals(%( groups => <g h>, items => <a b>, deal => Deal.new )),
      )
    });

    it 'reads a local passed to the template and both loop variables', {
      expect(html).to.include("href='/deals/7/h/b'");
    }
  }

  context 'inside a given block', {
    let(:html, {
      HAML.render(
        :src(q:to/HAML/),
          - given $status
            - when 'open'
              %a{href: "/deals/#{$deal.id}/#{$_}"} x
          HAML
        :locals(%( status => 'open', deal => Deal.new )),
      )
    });

    it 'reads a local passed to the template and the topic', {
      expect(html).to.include("href='/deals/7/open'");
    }
  }
}
