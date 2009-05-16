use strict;
use warnings;

package ExporterModule;

use Sub::Exporter -setup => {
    exports => ['stuff'],
};

sub stuff { }

1;
