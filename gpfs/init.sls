# -*- coding: utf-8 -*-
# vim: ft=sls

{% from "gpfs/map.jinja" import gpfs with context %}

{% if pillar['ofed'] is defined %}
include:
  - ofed.infiniband
{% endif %}

{% if gpfs.kernel_version is defined %}
{% set kernel_version=gpfs.kernel_version %}
{% else %}
{% set kernel_version=grains['kernelrelease'] + '.' + grains['osarch'] %}
{% endif %}

gpfs:
  pkgrepo.managed:
    - name: gpfs
    - humanname: GPFS RPMs
    - baseurl: http://{{ gpfs.repo.server }}{{ gpfs.repo.path }}
    - gpgcheck: 0
    - disabled: 1
  pkg.installed:
    - pkgs:
      - gpfs.base
      - gpfs.docs
      - gpfs.gpl
      - gpfs.gskit
      - gpfs.msg.en_US
{% if gpfs.version_type == "standard" or gpfs.version_type == "advanced" %}
      - gpfs.ext
{% if gpfs.gui_enabled %}
      - gpfs.gui
{% endif %}
{% if gpfs.version_type ==  "advanced" %}
      - gpfs.adv
      - gpfs.crypto
{% endif %}
{% endif %}
    - fromrepo: gpfs
    - refresh: True
    - require:
      - pkgrepo: gpfs
      - pkg: gpfsdeps
  file.managed:
    - name: /etc/init.d/gpfs
    - source: salt://gpfs/files/gpfs
    - follow_symlinks: False
    - user: root
    - group: root
    - mode: 555
    - require_in:
      - service: gpfs
  service.running:
    - name: gpfs
    - enable: True
    - require:
      - pkg: gpfs
      - file: gpfs
{%- if pillar['ofed'] is defined and pillar['ofed']['type'] == "mellanox" and (pillar['xcat'] is defined and "nicips.ib0" in pillar['xcat']['node'].iteritems()) %}
      - service: openibd
{%- endif %}

gpfsgplbin:
{% if not gpfs.rebuild %}
  pkg.installed:
    - name: gpfs.gplbin-{{ kernel_version }}
    - fromrepo: gpfs
    - refresh: True
    - require:
      - pkgrepo: gpfs
      - pkg: gpfsdeps
      - pkg: gpfs
{% else %}
{% if not gpfs.mcr %}
  cmd.run:
    - name: LINUX_DISTRIBUTION=REDHAT_AS_LINUX /usr/lpp/mmfs/bin/mmbuildgpl
    - require:
      - pkg: gplbuilddeps
{% else %}
  cmd.run:
    - name: >
        cd /usr/lpp/mmfs/src ;
        make World
    - unless: ls -l /usr/lpp/mmfs/src/bin/kdump-{{ kernel_version }}.{{ grains['osarch'] }}
    - require:
      - pkg: gplbuilddeps
      - file: env_mcr

env_mcr:
  file.managed:
    - name: /usr/lpp/mmfs/src/config/env.mcr
    - source: salt://gpfs/files/env.mcr.j2
    - template: jinja
    - makedirs: true
    - context:
      kernel_version: {{ kernel_version }}
      gpfs_kernel_version: {% for num in (kernel_version.split(".")|join("-")).split("-") %}{% if loop.index < 5 %}{% if loop.index == 1 %}{{num}}{% else %}{% if num|int < 10 %}0{{ num }}{% else %}{{ num }}{% endif %}{% endif %}{% endif %}{% endfor %}
{% endif %}

gplbuilddeps:
  pkg.installed:
    - pkgs:
      - gcc
      - gcc-c++
      - kernel-devel: {{ kernel_version }}
      - kernel-headers
      - make
      - perl
    - refresh: True
{% endif %}

gpfsdeps:
  pkg.latest:
    - pkgs:
      - ksh
      - libaio
      - m4
      - net-tools
      - perl
    - refresh: True

gpfs.profile.sh:
  file.managed:
    - name: /etc/profile.d/gpfs.sh
    - source: salt://gpfs/files/gpfs.sh
    - mode: 555

gpfs.profile.csh:
  file.managed:
    - name: /etc/profile.d/gpfs.csh
    - source: salt://gpfs/files/gpfs.csh
    - mode: 555
