# Sys::VirtV2V::GuestOS
# Copyright (C) 2009 Red Hat Inc.
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA

package Sys::VirtV2V::GuestOS;

use strict;
use warnings;

use Carp;
use File::Spec;
use File::Temp;

use Sys::VirtV2V::ExecHelper;
use Sys::VirtV2V::Util qw(user_message);

use Module::Pluggable sub_name => 'modules',
                      search_path => 'Sys::VirtV2V::GuestOS',
                      require => 1;

use Locale::TextDomain 'virt-v2v';

=pod

=head1 NAME

Sys::VirtV2V::GuestOS - Manipulate and query a Guest OS

=head1 SYNOPSIS

 use Sys::VirtV2V::GuestOS;

 $guestos = Sys::VirtV2V::GuestOS->new($g, $desc, $dom, $config);

=head1 DESCRIPTION

Sys::VirtV2V::GuestOS provides a mechanism for querying and manipulating a
specific guest operating system.

Sys::VirtV2V::GuestOS is a virtual superclass to various backends, each of which
implement a consistent API. The new method will actually instantiate an
appropriate subclass.

Sys::VirtV2V::GuestOS uses L<Module::Pluggable> to automatically discover
backends under Sys::VirtV2V::GuestOS.

=head1 METHODS

=over

=item new(g, desc, dom, config)

Instantiate a GuestOS object capable of manipulating the target OS.

=over

=item g

A L<Sys::Guestfs> handle.

=item desc

An OS description created by L<Sys::Guestfs::Lib>.

=item dom

An XML::DOM object containing the guest's libvirt domain XML prior to
conversion.

=item config

An XML::DOM object containing the virt-v2v configuration.

=back

Returns a capable Sys::VirtV2V::GuestOS if one is found.

Returns undef otherwise.

=cut

sub new
{
    my $class = shift;

    my ($g, $desc, $dom, $config) = @_;
    defined($g)      or carp("instantiate called without g argument");
    defined($desc)   or carp("instantiate called without desc argument");
    defined($dom)    or carp("instantiate called without dom argument");
    defined($config) or carp("instantiate called without config argument");

    my $self = {};

    $self->{g}      = $g;
    $self->{desc}   = $desc;
    $self->{dom}    = $dom;
    $self->{config} = $config;

    foreach my $module ($class->modules()) {
        return $module->new($self)
            if($module->can_handle($desc));
    }

    return undef;
}

=item get_ncpus

Return the number of CPUS which are available to this guest

=cut

sub get_ncpus
{
    my $self = shift;

    my ($ncpus) = $self->{dom}->findnodes('/domain/vcpu/text()');
    if (defined($ncpus)) {
        return $ncpus->getData();
    } else {
        return 1;
    }
}

=item get_memory_kb

Return the amount of memory, in KB, which is available to this guest

=cut

sub get_memory_kb
{
    my $self = shift;

    my ($mem_kb) = $self->{dom}->findnodes('/domain/memory/text()');

    return $mem_kb->getData();
}

=back

=head1 BACKEND INTERFACE

All GuestOS backends are required to implement the following methods:

=over

=item CLASS->can_handle(desc)

=over

=item desc

An OS description as returned by L<Sys::Guestfs::Lib>.

=back

Returns true if the backend can handle the guest described by L<desc>.

can_handle is only intended to be called by Sys::VirtV2V::GuestOS.

=item CLASS->new(g, desc, files, deps, aliases)

=over

=item g

A L<Sys::Guestfs> handle.

=item desc

An OS description created by L<Sys::Guestfs::Lib>.

=item dom

A parsed XML::DOM containing the libvirt domain XML for this guest prior to any
conversion.

=item config

A parsed XML::DOM containing the virt-v2v configuration, or undef if there is
no config.

=back

Construct a new backend object. Assumes can_handle has previously returned true.

new is only intended to be called by Sys::VirtV2V::GuestOS.

=item enable_kernel_module(device, module)

=over

=item device

The name of the device as it is known to modprobe. Examples are I<eth0> or
I<scsi_hostadapter>.

=item module

The name of the kernel module which should be loaded for this device. An example
is I<virtio_blk>.

=back

enable_kernel_module adds a new kernel module to the modprobe configuration.

=item update_kernel_module(device, module)

See enable_kernel_module for argument descriptions.

update_kernel_module changes an existing modprobe configuration in place.

=item disable_kernel_module(device)

See enable_kernel_module for argument description.

disable_kernel_module removes the modprobe configuration for the given device.

=item update_display_driver(driver)

=over

=item driver

The name of the new disply driver. An example is I<cirrus>.

=back

Update the display driver, if defined, to the given driver.

=item remove_kernel(version)

=over

=item version

The version number of the kernel to be removed.

=back

remove_kernel uninstalls a kernel from the guest.

=item get_application_owner(file)

=over

=item file

The absolute path to a file or directory on the guest.

=back

Return the name of the application which owns the given file.

get_application_owner() will throw an exception if the file is not owned by any
application.

=item remap_block_devices(map)

=over

=item map

A map of old names to new names specified as (old1 => new1, old2 => new2...).

=back

Update the guest to reflect the renaming of block devices.

=item prepare_bootable(version [, module, module, ...])

=over

=item version

The version number of the kernel which we want to boot.

=item module

A module which must be available at boot time.

=back

Ensure that the guest will boot the given kernel version by default, and it will
make available the given modules

=item supports_virtio(kernel)

=over

=item kernel

The version number of the kernel to be inspected

=back

Returns 1 if the target kernel supports virtio, 0 otherwise.

=back

=head1 COPYRIGHT

Copyright (C) 2009 Red Hat Inc.

=head1 LICENSE

Please see the file COPYING.LIB for the full license.

=head1 SEE ALSO

L<virt-v2v(1)>,
L<Sys::VirtV2V::GuestOS::RedHat(3pm)>,
L<Sys::Guestfs(3pm)>,
L<Sys::Guestfs::Lib(3pm)>,
L<http://libguestfs.org/>.

=cut

1;
