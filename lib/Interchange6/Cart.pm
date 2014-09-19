# Interchange6::Cart - Interchange6 cart class

package Interchange6::Cart;

=head1 NAME 

Interchange6::Cart - Cart class for Interchange6 Shop Machine

=cut

use strict;
use Carp;
use DateTime;
use Interchange6::Cart::Cost;
use Interchange6::Cart::Product;
use Scalar::Util 'blessed';
use Try::Tiny;
use Moo;
use MooseX::CoverableModifiers;
use MooX::HandlesVia;
use Interchange6::Types;
use Interchange6::Hook;

with 'Interchange6::Role::Costs';
with 'Interchange6::Role::Errors';
with 'Interchange6::Role::Hookable';

use namespace::clean;

=head1 DESCRIPTION

Generic cart class for L<Interchange6>.

See L<Interchange6::Role::Costs> for details of cost attributes and methods.

=head1 SYNOPSIS

  my $cart = Interchange6::Cart->new();

  $cart->add( sku => 'ABC', name => 'Foo', price => 23.45 );

  $cart->update( sku => 'ABC', quantity => 3 );

  my $product = Interchange::Cart::Product->new( ... );

  $cart->add($product);

  $cart->apply_cost( ... );

  my $total = $cart->total;

=head1 ATTRIBUTES

Date and time cart was created.

=head2 id

Cart id can be used for subclasses, e.g. primary key value for carts in the database.

=cut

has id => (
    is  => 'rw',
    isa => Str,
);

=head2 created

Returns the time the cart was created as a DateTime object.

=cut

has created => (
    is      => 'ro',
    isa     => DateAndTime,
    default => sub { DateTime->now },
);

=head2 last_modified

Returns the time the cart was last modified as a DateTime object.

=cut

has last_modified => (
    is      => 'rwp',
    isa     => DateAndTime,
    default => sub { DateTime->now },
);

=head2 name

The cart name. Default is 'main'.

=cut

has name => (
    is       => 'rw',
    isa      => AllOf [ Defined, NotEmpty, VarChar [255] ],
    default  => 'main',
    required => 1,
);

around name => sub {
    my ( $orig, $self ) = ( shift, shift );

    if ( @_ > 0 ) {

        my $old_name = $self->name;

        $self->clear_error;
        # run hook before renaming the cart
        $self->execute_hook( 'before_cart_rename', $self, $old_name, $_[0] );
        return if $self->has_error;

        # fire off the rename
        my $ret = $orig->( $self, @_ );

        $self->_set_last_modified( DateTime->now );

        # run hook after clearing the cart
        $self->execute_hook( 'after_cart_rename', $self, $old_name, $_[0] );

        return $ret;
    }
    else {
        return $orig->( $self );
    }
};

=head2 products

In addition to the standard accessors products has a number of private methods supplied to us via <MooX::HandlesVia> which are documented under L</PRODUCT METHODS> below.

=cut

has products => (
    is  => 'rwp',
    isa => ArrayRef [ InstanceOf ['Interchange::Cart::Product'] ],
    default     => sub { [] },
    handles_via => 'Array',
    handles     => {
        clear          => 'clear',
        count          => 'count',
        is_empty       => 'is_empty',
        product_get    => 'get',
        product_index  => 'first_index',
        products_array => 'elements',
        _delete        => 'delete',
        _product_push  => 'push',
        _product_set   => 'set',
    },
    reader   => 'get_products',
    init_arg => undef,
);

sub products {
    my $self = shift;
    return $self->get_products;
}

=head2 sessions_id

The session ID for the cart.

=cut

has sessions_id => (
    is      => 'rw',
    clearer => 1,
);

around sessions_id => sub {
    my ( $orig, $self ) = ( shift, shift );

    if ( @_ > 0 ) {

        my %data = ( sessions_id => $_[0] );

        $self->execute_hook( 'before_cart_set_sessions_id', $self, \%data );
        return if $self->has_error;

        my $ret = $orig->( $self, @_ );

        $self->execute_hook( 'after_cart_set_sessions_id', $self, \%data );

        return $ret;
    }
    else {
        return $orig->( $self );
    }
};

=head2 users_id

The user id of the logged in user.

=cut

has users_id => (
    is     => 'rwp',
    isa    => Str,
    reader => 'get_users_id',
    writer => '_set_users_id',
);

sub users_id {
    my ( $self, $users_id ) = @_;

    if ( @_ > 1 ) {

        # set users_id for the cart
        my %data = ( users_id => $users_id );

        $self->execute_hook( 'before_cart_set_users_id', $self, \%data );
        return if $self->has_error;

        $self->_set_users_id($users_id);

        $self->execute_hook( 'after_cart_set_users_id', $self, \%data );
    }

    return $self->get_users_id;
}

=head1 PRODUCT METHODS

=head2 clear

Removes all products from the cart.

=cut

around clear => sub {
    my ( $orig, $self ) = ( shift, shift );

    $self->clear_error;

    # run hook before clearing the cart
    $self->execute_hook( 'before_cart_clear', $self );
    return if $self->has_error;

    # fire off the clear
    $orig->( $self, @_ );

    $self->_set_last_modified( DateTime->now );

    # run hook after clearing the cart
    $self->execute_hook( 'after_cart_clear', $self );

    return;
};

=head2 count

Returns the number of different products in the shopping cart. If you have 5 apples and 6 pears it will return 2 (2 different products).

=head2 get_products

Returns an arrayref of Interchange::Cart::Product(s)

=head2 is_empty

Return boolean 1 or 0 depending on whether the cart is empty or not.

=head2 product_get $index

Returns the product at the specified index;

=head2 product_index( sub {...})

This method returns the index of the first matching product in the cart. The matching is done with a subroutine reference you pass to this method. The subroutine will be called against each element in the array until one matches or all elements have been checked.

This method requires a single argument.

  my $index = $cart->product_index( sub { $_->sku eq 'ABC' } );

=head2 products

An alias for get_products for backwards compatibility.

=head2 products_array

Returns an array of Interchange::Cart::Product(s)


=head1 OTHER METHODS

=head2 new

Inherited method. Returns a new Cart object.

=head2 add($product)

Add product to the cart. Returns product in case of success.

The product is an L<Interchange6::Cart::Product> or a hash (reference) of product attributes that would be passed to Interchange6::Cart::Product->new(). See L<Interchange6::Cart::Product> for details.

=cut

=head2 add

=cut

sub add {
    my $self    = shift;
    my $product = $_[0];
    my ( $index, $oldproduct, $update );

    $self->clear_error;

    if ( blessed($product) ) {
        die "product argument is not an Interchange6::Cart::Product"
          unless ( $product->isa('Interchange6::Cart::Product') );
    }
    else {

        # we got a hash(ref) rather than an Product

        my %args;

        if ( is_HashRef($product) ) {

            # copy args
            %args = %{$product};
        }
        else {

            %args = @_;
        }

        # run hooks before validating product

        $self->execute_hook( 'before_cart_add_validate', $self, \%args );
        return if $self->has_error;

        $product = 'Interchange6::Cart::Product'->new(%args);

        unless ( blessed($product)
            && $product->isa('Interchange6::Cart::Product') )
        {
            $self->set_error("failed to create product.");
            return;
        }
    }

    # $product is now an Interchange6::Cart::Product so run hook

    $self->execute_hook( 'before_cart_add', $self, $product );
    return if $self->has_error;

   # cart may already contain an product with the same sku
   # if so then we add quantity to existing product otherwise we add new product

    $index = $self->product_index( sub { $_->sku eq $product->sku } );

    if ( $index >= 0 ) {

        # product already exists in cart so we need to add new quantity to old

        $oldproduct = $self->product_get($index);

        $product->quantity( $oldproduct->quantity + $product->quantity );

        $self->_product_set( $index, $product );

        $update = 1;
    }
    else {

        # a new product for this cart

        $self->_product_push($product);
    }

    # final hook
    $self->execute_hook( 'after_cart_add', $self, $product, $update );

    $self->_set_last_modified( DateTime->now );

    return $product;
}

=head2 add_hook( $hook );

This binds a coderef to an installed hook.

  $hook = Interchange6::Hook->new(
      name => 'before_cart_remove',
      code => sub {
          my ( $cart, $product ) = @_;
          if ( $product->sku eq '123' ) {
              $cart->set_error('Product not removed due to hook.');
          }
      }
  )

  $cart->add_hook( $hook );

See L</HOOKS> for details of the available hooks.

=cut

around add_hook => sub {
    my ( $orig, $self ) = ( shift, shift );
    my ($hook) = @_;
    my $name = $hook->name;

    # if that hook belongs to the app, register it now and return
    return $self->$orig(@_) if $self->has_hook($name);

    # for now extra hooks cannot be added so die if we got here
    croak "add_hook failed";
};

=head2 find

Searches for an cart product with the given SKU.
Returns cart product in case of sucess or undef on failure.

  if ($product = $cart->find(9780977920174)) {
      print "Quantity: $product->{quantity}.\n";
  }

=cut

sub find {
    my ( $self, $sku ) = @_;

    for my $cartproduct ( $self->products_array ) {
        if ( $sku eq $cartproduct->sku ) {
            return $cartproduct;
        }
    }

    return undef;
}

=head2 quantity

Returns the sum of the quantity of all products in the shopping cart,
which is commonly used as number of products. If you have 5 apples and 6 pears it will return 11.

  print 'Products in your cart: ', $cart->quantity, "\n";

=cut

sub quantity {
    my $self = shift;
    my $qty  = 0;

    for my $product ( $self->products_array ) {
        $qty += $product->quantity;
    }

    return $qty;
}

=head2 remove($sku)

Remove product from the cart. Takes SKU of product to identify the product.

=cut

sub remove {
    my ( $self, $arg ) = @_;
    my ( $index, $product );

    $self->clear_error unless caller eq __PACKAGE__;

    # run hook before locating product
    $self->execute_hook( 'before_cart_remove_validate', $self, $arg );
    return if $self->has_error;

    $index = $self->product_index( sub { $_->sku eq $arg } );

    if ( $index >= 0 ) {

        # run hooks before adding product to cart
        $product = $self->product_get($index);

        $self->execute_hook( 'before_cart_remove', $self, $product );
        return if $self->has_error;

        # remove product from our array
        $self->_delete($index);

        # reset totals & modified before calling hook
        #$self->clear_subtotal;
        #$self->clear_total;
        $self->_set_last_modified( DateTime->now );

        $self->execute_hook( 'after_cart_remove', $self, $product );
        return if $self->has_error;

        return 1;
    }

    # product missing
    $self->set_error("Product not found in cart: $arg.");
    return;
}

=head2 seed $product_ref

Seeds products within the cart from $product_ref.

B<NOTE:> use with caution since any existing products in the cart will be lost and since cart hooks are not executed since $cart->add is not used.

  $cart->seed([
      { sku => 'BMX2015', price => 20, quantity = 1 },
      { sku => 'KTM2018', price => 400, quantity = 5 },
      { sku => 'DBF2020', price => 200, quantity = 5 },
  ]);

=cut

sub seed {
    my ( $self, $product_ref ) = @_;
    my ( $args, $product, @errors );

  PRODUCT: for $args ( @{ $product_ref || [] } ) {

        # stash any existing error
        push( @errors, $self->error ) if $self->has_error;

        $product = Interchange6::Cart::Product->new($args);
        unless ( blessed($product)
            && $product->isa('Interchange6::Cart::Product') )
        {
            $self->set_error("failed to create product.");
            next PRODUCT;
        }

        $self->_product_push($product);
    }
    push( @errors, $self->error ) if $self->has_error;
    $self->set_error( join( ":", @errors ) ) if scalar(@errors) > 1;

    return $self->products;
}


=head2 subtotal

Returns current cart subtotal excluding costs.

=head2 total

Returns current cart total including costs.

=cut

sub subtotal {
    my $self = shift;

    my $subtotal = 0;

    for my $product ( $self->products_array ) {
        $subtotal += $product->total;
    }

    return $subtotal;
}

=head2 update

Update quantity of products in the cart.

Parameters are pairs of SKUs and quantities, e.g.

  $cart->update(9780977920174 => 5,
                9780596004927 => 3);

Triggers before_cart_update and after_cart_update hooks.

A quantity of zero is equivalent to removing this product,
so in this case the remove hooks will be invoked instead
of the update hooks.

=cut

sub update {
    my ( $self, @args ) = @_;
    my ( $sku, $qty, $product, $update, @errors );

    $self->clear_error;

  ARGS: while ( @args > 0 ) {
        $sku = shift @args;
        $qty = shift @args;

        # stash any existing error
        push( @errors, $self->error ) if $self->has_error;

        unless ( $product = $self->find($sku) ) {
            $self->set_error("Product for $sku not found in cart.");
            next ARGS;
        }

        if ( $qty == 0 ) {

            $self->remove($sku);
            next;
        }

        # jump to next product if quantity stays the same
        next if $qty == $product->quantity;

        # run hook before updating the cart
        $update = { quantity => $qty };

        $self->execute_hook( 'before_cart_update', $self, $product, $update );
        next ARGS if $self->has_error;

        $product->quantity($qty);

        #$self->clear_subtotal;
        #$self->clear_total;
        $self->_set_last_modified( DateTime->now );

        $self->execute_hook( 'after_cart_update', $self, $product, $update );
    }
    push( @errors, $self->error ) if $self->has_error;
    $self->set_error( join( ":", @errors ) ) if scalar(@errors) > 1;
}

=head1 HOOKS

The following hooks are available:

=over 4

=item before_cart_add_validate

Called in L</add> for items added as hash(ref)s. Not called for products passed into L</add> that are already L<Interchange6::Cart::Product> objects.

Receives: $cart, \%args

=item before_cart_add

Called in L</add> immediately before the Interchange6::Cart::Product is added to the cart.

Receives: $cart, $product

=item after_cart_add

Called in L</add> after product has been added to the cart.

Receives: $cart, $product

=item before_cart_remove_validate

Called at start of L</remove> before arg has been validated.

Receives: $cart, $sku

=item before_cart_remove

Called in L</remove> before product is removed from cart.

Receives: $cart, $product

=item after_cart_remove

Called in L</remove> after product has been removed from cart.

Receives: $cart, $product

=item before_cart_update

=item after_cart_update

=item before_cart_clear

=item after_cart_clear

=item before_cart_set_users_id

=item after_cart_set_users_id

=item before_cart_set_sessions_id

=item after_cart_set_sessions_id

=item before_cart_rename

=item after_cart_rename

=back

=head1 AUTHORS

 Stefan Hornburg (Racke), <racke@linuxia.de>
 Peter Mottram (SysPete), <peter@sysnix.com>

=head1 LICENSE AND COPYRIGHT

Copyright 2011-2014 Stefan Hornburg (Racke) <racke@linuxia.de>.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
