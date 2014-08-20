# Interchange6::Cart::Product - Interchange6 cart product class

package Interchange6::Cart::Product;

use strict;
use Moo;
use Interchange6::Types;
use MooX::HandlesVia;

use namespace::clean;

=head1 NAME 

Interchange6::Cart::Product - Cart product class for Interchange6 Shop Machine

=head1 DESCRIPTION

Cart product class for L<Interchange6>.

=head2 ITEM ATTRIBUTES

Each cart product has the following attributes:

=over 4

=item cart_products_id

Can be used by subclasses to tie cart products to L<Interchange6::Schema::Result::CartProduct>.

=cut

has cart_products_id => (
    is => 'ro',
    isa => Int,
);

=item sku

Unique product identifier is required.

=cut

has sku => (
    is       => 'ro',
    isa      => AllOf [ Defined, NotEmpty, VarChar [32] ],
    required => 1,
);

=item name

Product name is required.

=cut

has name => (
    is       => 'ro',
    isa      => AllOf [ Defined, NotEmpty, VarChar [255] ],
    required => 1,
);

=item quantity

Product quantity is optional and has to be a natural number greater
than zero. Default for quantity is 1.

=cut

has quantity => (
    is      => 'rw',
    isa     => AllOf [ PositiveNum, Int ],
    default => 1,
);

=item price

Product price is required and a positive number.

Price is required, because you want to maintain the price that was valid at the time of adding to the cart. Should the price in the shop change in the meantime, it will maintain this price. If you would like to update the pages, you have to do it before loading the cart page on your shop.

=cut

has price => (
    is       => 'ro',
    isa      => AllOf [ Defined, PositiveNum ],
    required => 1,
);

=item uri

Product uri

=cut

has uri => (
    is       => 'rw',
    isa      => VarChar [255],
);

=item attributes

Product attributes hashref to store things such as size, colour, etc.

=cut

has attributes => (
    is  => 'rw',
    isa => HashRef,
    default => sub { {} },
    handles => {
        clear_attributes => 'clear',
        add_attribute    => 'set',
    }
);

=back

=head1 METHODS

=head2 add_attribute( $key => $value, $key2 => $value2...)

Add one or more key/value pair to L</attributes>.

=head2 all_attributes

Returns the key/value pairs in L</attributes> as a flattened list.

=head2 clear_attributes

Clears the L</attributes> attribute.

=head2 subtotal

Returns subtotal for this cart product.
The subtotal is calculated by the multiplication of price and quantity.

=cut

sub subtotal {
    my ($self) = @_;

    return $self->price * $self->quantity;
};

1;
