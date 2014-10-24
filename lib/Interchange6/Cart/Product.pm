# Interchange6::Cart::Product - Interchange6 cart product class

package Interchange6::Cart::Product;

use strict;
use Moo;
use Interchange6::Types;
with 'Interchange6::Role::Costs';

use namespace::clean;

=head1 NAME 

Interchange6::Cart::Product - Cart product class for Interchange6 Shop Machine

=head1 DESCRIPTION

Cart product class for L<Interchange6>.

See L<Interchange6::Role::Costs> for details of cost attributes and methods.

=head1 ATTRIBUTES

Each cart product has the following attributes:

=head2 id

Can be used by subclasses, e.g. primary key value for cart products in the database.

=cut

has id => (
    is  => 'ro',
    isa => Int,
);

=head2 cart

A reference to the Cart object that this Cart::Product belongs to.

=cut

has cart => (
    is        => 'rw',
    default   => undef,
);

=head2 name

Product name is required.

=cut

has name => (
    is       => 'ro',
    isa      => AllOf [ Defined, NotEmpty, VarChar [255] ],
    required => 1,
);

=head2 price

Price is required must be a positive number or zero.

=cut

has price => (
    is       => 'ro',
    isa      => AnyOf [ PositiveNum, Zero ],
    required => 1,
);

=head2 selling_price

Product L</price> after any discounts have been applied by group pricing, tier pricing, etc. Defaults to L</price>.

=cut

has selling_price => (
    is      => 'rw',
    isa     => AnyOf [ PositiveNum, Zero ],
    builder => 1,
    lazy    => 1,
);

sub _build_selling_price {
    return shift->price;
}

=head2 quantity

Product quantity is optional and has to be a natural number greater
than zero. Default for quantity is 1.

=cut

has quantity => (
    is      => 'rw',
    isa     => AllOf [ PositiveNum, Int ],
    default => 1,
);

=head2 sku

Unique product identifier is required.

=cut

has sku => (
    is       => 'ro',
    isa      => AllOf [ Defined, NotEmpty, VarChar [32] ],
    required => 1,
);

=head2 subtotal

Subtotal calculated as L</selling_price> * L</quantity>. Lazy set via builder.

=cut

has subtotal => (
    is        => 'lazy',
    isa       => Num,
    clearer   => 1,
    predicate => 1,
);

sub _build_subtotal {
    my $self = shift;
    return sprintf( "%.2f", $self->selling_price * $self->quantity);
}

=head2 total

Total calculated as L</subtotal> plus all L<Interchange6::Role:Costs/costs>.

=cut

has total => (
    is        => 'lazy',
    isa       => Num,
    clearer   => 1,
    predicate => 1,
);

sub _build_total {
    my $self = shift;
    my $subtotal = $self->subtotal;
    return sprintf( "%.2f", $subtotal + $self->_calculate($subtotal) );
}

=head2 uri

Product uri

=cut

has uri => (
    is  => 'rw',
    isa => VarChar [255],
);

=head2 combine

This flag determines whether multiple quantities of this product can be combined into a single line in the cart or whether each single product with this sku must be recorded as a single line item. This can be used when individual products are to be personalised. Default is 1 (true). Value can also be a coderef which is used to determine true or false.

=cut

has combine => (
    is => 'ro',
    isa => AnyOf[ Bool, CodeRef ],
    default => 1,
);

=head1 METHODS

=head2 clear_subtotal

clears L</subtotal>.

=head2 clear_total

clears L</total>.

=head2 has_subtotal

predicate on L</subtotal>.

=head2 has_total

predicate on L</total>.

=cut

# after charge changes we need to clear the total

after apply_charge => sub {
    my $self = shift;
    $self->clear_total;
    if ( $self->cart ) {
        $self->cart->clear_subtotal;
        $self->cart->clear_total;
    }
};

after clear_charges => sub {
    my $self = shift;
    $self->clear_total;
    if ( $self->cart ) {
        $self->cart->clear_subtotal;
        $self->cart->clear_total;
    }
};

1;
