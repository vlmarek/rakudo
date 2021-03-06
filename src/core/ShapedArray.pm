# this is actually part of the Array class

    my role ShapedArray does Rakudo::Internals::ShapedArrayCommon {
        has $.shape;

        proto method AT-POS(|) is raw {*}
        multi method AT-POS(Array:U: |c) is raw {
            self.Any::AT-POS(|c)
        }
        multi method AT-POS(Array:D:) is raw {
            die "Must specify at least one index with AT-POS"
        }

        # Handle dimensions > 3 or more indices than dimensions.
        # If dimensions <= 3, then custom AT-POS should have caught
        # correct number of indices already.
        multi method AT-POS(Array:D: **@indices) is raw {
            nqp::stmts(
              (my $reified := nqp::getattr(self,List,'$!reified')),
              nqp::if(
                nqp::islt_i(
                  @indices.elems,                    # reifies
                  (my int $numdims = nqp::numdimensions($reified))
                ),
                X::NYI.new(
                  feature => "Partially dimensioned views of arrays").throw,
                nqp::stmts(
                  (my $indices := nqp::getattr(@indices,List,'$!reified')),
                  (my $idxs := nqp::list_i),
                  nqp::while(                        # native index list
                    nqp::isge_i(($numdims = nqp::sub_i($numdims,1)),0),
                    nqp::push_i($idxs,nqp::shift($indices))
                  ),
                  (my $element := nqp::ifnull(
                    nqp::atposnd($reified,$idxs),    # found it
                    nqp::p6bindattrinvres(           # create container
                      (my $scalar := nqp::p6scalarfromdesc(
                        nqp::getattr(self,Array,'$!descriptor'))),
                      Scalar,
                      '$!whence',
                      -> { nqp::bindposnd($reified,$idxs,$scalar) }
                    )
                  )),
                  nqp::if(
                    nqp::elems($indices),
                    $element.AT-POS(|@indices),      # index further
                    $element                         # we're done!
                  )
                )
              )
            )
        }

        proto method ASSIGN-POS(|) {*}
        multi method ASSIGN-POS(Array:U: |c) {
            self.Any::ASSIGN-POS(|c)
        }
        multi method ASSIGN-POS(Array:D:) {
            die "Must specify at least one index and a value with ASSIGN-POS"
        }
        multi method ASSIGN-POS(Array:D: $) {
            die "Must specify at least one index and a value with ASSIGN-POS"
        }

        multi method ASSIGN-POS(**@indices) {
            nqp::stmts(
              (my $value   := @indices.pop),         # reifies
              (my $indices := nqp::getattr(@indices,List,'$!reified')),
              (my $reified := nqp::getattr(self,List,'$!reified')),
              nqp::if(
                nqp::isge_i(
                  (my int $numind  = nqp::elems($indices)),
                  (my int $numdims = nqp::numdimensions($reified))
                ),
                nqp::stmts(                          # more than enough indices
                  (my $idxs := nqp::list_i),
                  nqp::while(                        # native index list
                    nqp::isge_i(($numdims = nqp::sub_i($numdims,1)),0),
                    nqp::push_i($idxs,nqp::shift($indices))
                  ),
                  (my $element := nqp::ifnull(
                    nqp::atposnd($reified,$idxs),    # found it!
                    nqp::bindposnd($reified,$idxs,   # create new scalar
                      nqp::p6scalarfromdesc(
                        nqp::getattr(self,Array,'$!descriptor')))
                  )),
                  nqp::if(
                    nqp::elems($indices),
                    $element.AT-POS(|@indices),      # go deeper
                    $element                         # this is it
                  ) = $value                         # and assign
                ),
                X::NotEnoughDimensions.new(          # too few indices
                  operation         => 'assign to',
                  got-dimensions    => $numind,
                  needed-dimensions => $numdims
                ).throw
              )
            )
        }

        proto method EXISTS-POS(|) {*}
        multi method EXISTS-POS(Array:U: |c) {
            self.Any::EXISTS-POS(|c)
        }
        multi method EXISTS-POS(Array:D:) {
            die "Must specify at least one index with EXISTS-POS"
        }

        multi method EXISTS-POS(**@indices) {
            nqp::p6bool(
              nqp::stmts(
                (my int $numind = @indices.elems),     # reifies
                (my $indices := nqp::getattr(@indices,List,'$!reified')),
                (my $reified := nqp::getattr(self,List,'$!reified')),
                (my $dims    := nqp::dimensions($reified)),
                (my int $i = -1),
                nqp::if(
                  nqp::isge_i(
                    $numind,
                    (my int $numdims = nqp::numdimensions($reified)),
                  ),
                  nqp::stmts(                          # same or more indices
                    (my $idxs := nqp::list_i),
                    nqp::while(
                      nqp::islt_i(                     # still indices left
                        ($i = nqp::add_i($i,1)),
                        $numind)
                        && nqp::islt_i(                # within range?
                             (my $idx = nqp::shift($indices)),
                             nqp::atpos_i($dims,$i)),
                      nqp::push_i($idxs,$idx)
                    ),
                    nqp::if(
                      nqp::iseq_i($i,$numind)
                        && nqp::not_i(
                             nqp::isnull(nqp::atposnd($reified,$idxs))),
                      nqp::unless(                     # base pos exists
                        nqp::not_i(nqp::elems($indices)),
                        nqp::atposnd($reified,$idxs).EXISTS-POS(|@indices)
                      )
                    )
                  ),
                  nqp::stmts(                          # fewer inds than dims
                    nqp::while(
                      nqp::islt_i(($i = nqp::add_i($i,1)),$numind)
                        && nqp::islt_i(
                             nqp::atpos($indices,$i),
                             nqp::atpos_i($dims,$i)),
                      nqp::null
                    ),
                    nqp::iseq_i($i,$numind)            # all clear or oor
                  )
                )
              )
            )
        }

        proto method DELETE-POS(|) {*}
        multi method DELETE-POS(Array:U: |c) {
            self.Any::DELETE-POS(|c)
        }
        multi method DELETE-POS(Array:D:) is raw {
            die "Must specify at least one index with DELETE-POS"
        }

        multi method DELETE-POS(**@indices) {
            nqp::stmts(
              (my int $numind = @indices.elems),     # reifies
              (my $indices := nqp::getattr(@indices,List,'$!reified')),
              (my $reified := nqp::getattr(self,List,'$!reified')),
              (my int $i = -1),
              nqp::if(
                nqp::isge_i(
                  $numind,
                  (my int $numdims = nqp::numdimensions($reified)),
                ),
                nqp::stmts(                          # same or more indices
                  (my $idxs := nqp::list_i),
                  nqp::while(
                    nqp::islt_i(                     # still indices left
                      ($i = nqp::add_i($i,1)),$numind),
                    nqp::push_i($idxs,nqp::shift($indices)),
                  ),
                  nqp::if(
                    nqp::isnull(my $value := nqp::atposnd($reified,$idxs)),
                    Nil,                             # nothing here
                    nqp::if(
                      nqp::elems($indices),
                      $value.DELETE-POS(|@indices),  # delete at deeper level
                      nqp::stmts(                    # found it, nullify here
                        nqp::bindposnd($reified,$idxs,nqp::null),
                        $value
                      )
                    )
                  )
                ),
                X::NotEnoughDimensions.new(          # fewer inds than dims
                  operation         => 'delete from',
                  got-dimensions    => $numind,
                  needed-dimensions => $numdims
                ).throw
              )
            )
        }

        proto method BIND-POS(|) is raw {*}
        multi method BIND-POS(Array:U: |c) is raw {
            self.Any::BIND-POS(|c)
        }
        multi method BIND-POS(Array:D:) {
            die "Must specify at least one index and a value with BIND-POS"
        }
        multi method BIND-POS(Array:D: $) {
            die "Must specify at least one index and a value with BIND-POS"
        }

        multi method BIND-POS(Array:D: **@indices) is raw {
            nqp::stmts(
              (my $value   := nqp::decont(@indices.pop)), # reifies
              (my $indices := nqp::getattr(@indices,List,'$!reified')),
              (my $reified := nqp::getattr(self,List,'$!reified')),
              (my int $i = -1),
              nqp::if(
                nqp::isge_i(
                  (my int $numind  = nqp::elems($indices)),
                  (my int $numdims = nqp::numdimensions($reified)),
                ),
                nqp::stmts(                               # same or more indices
                  (my $idxs := nqp::list_i),
                  nqp::while(
                    nqp::islt_i(                          # still indices left
                      ($i = nqp::add_i($i,1)),$numind),
                    nqp::push_i($idxs,nqp::shift($indices))
                  ),
                  nqp::if(
                    nqp::elems($indices),
                    nqp::atposnd($reified,$idxs)          # bind at deeper level
                      .BIND-POS(|@indices,$value),
                    nqp::bindposnd($reified,$idxs,        # found it, bind here
                      $value)
                  )
                ),
                X::NotEnoughDimensions.new(               # fewer inds than dims
                  operation         => 'bind to',
                  got-dimensions    => $numind,
                  needed-dimensions => $numdims
                ).throw
              )
            )
        }

        sub MEMCPY(Mu \to, Mu \from) {
            class :: does Rakudo::Internals::ShapeLeafIterator {
                has $!from;
                has $!desc;
                method INIT(Mu \to, Mu \from) {
                    nqp::stmts(
                      ($!from := nqp::getattr(from,List,'$!reified')),
                      ($!desc := nqp::getattr(from,Array,'$!descriptor')),
                      self.SET-SELF(to.shape,to)
                    )
                }
                method new(Mu \to, Mu \from) { nqp::create(self).INIT(to,from) }
                method result(--> Nil) {
                    nqp::ifnull(
                      nqp::atposnd($!list,$!indices),
                      nqp::bindposnd($!list,$!indices,
                        nqp::p6scalarfromdesc($!desc))
                    ) = nqp::atposnd($!from,$!indices)
                }
            }.new(to,from).sink-all
        }
        sub INTCPY(Mu \to, Mu \from) {
            class :: does Rakudo::Internals::ShapeLeafIterator {
                has $!from;
                method INIT(Mu \to, Mu \from) {
                    nqp::stmts(
                      ($!from := from),
                      self.SET-SELF(to.shape,to)
                    )
                }
                method new(Mu \to, Mu \from) { nqp::create(self).INIT(to,from) }
                method result(--> Nil) {
                    nqp::ifnull(
                      nqp::atposnd($!list,$!indices),
                      nqp::bindposnd($!list,$!indices,nqp::p6scalarfromdesc(Mu))
#?if moar
                      ) = nqp::multidimref_i($!from,$!indices)
#?endif
#?if !moar
                      ) = nqp::atposnd_i($!from,$!indices)
#?endif
                }
            }.new(to,from).sink-all
        }
        sub NUMCPY(Mu \to, Mu \from) {
            class :: does Rakudo::Internals::ShapeLeafIterator {
                has $!from;
                method INIT(Mu \to, Mu \from) {
                    nqp::stmts(
                      ($!from := from),
                      self.SET-SELF(to.shape,to)
                    )
                }
                method new(Mu \to, Mu \from) { nqp::create(self).INIT(to,from) }
                method result(--> Nil) {
                    nqp::ifnull(
                      nqp::atposnd($!list,$!indices),
                      nqp::bindposnd($!list,$!indices,nqp::p6scalarfromdesc(Mu))
#?if moar
                      ) = nqp::multidimref_n($!from,$!indices)
#?endif
#?if !moar
                      ) = nqp::atposnd_n($!from,$!indices)
#?endif
                }
            }.new(to,from).sink-all
        }

        proto method STORE(|) { * }
        multi method STORE(::?CLASS:D: ::?CLASS:D \in) {
            nqp::if(
              in.shape eqv self.shape && nqp::eqaddr(in.WHAT,self.WHAT),
              MEMCPY(self,in),       # VM-supported memcpy-like thing?
              X::Assignment::ArrayShapeMismatch.new(
                source-shape => in.shape,
                target-shape => self.shape
              ).throw
            )
        }
        multi method STORE(::?CLASS:D: array:D \in) {
            nqp::if(
              in.shape eqv self.shape,
              nqp::if(
                nqp::istype(in.of,Int),
                INTCPY(self,in),       # copy from native int
                NUMCPY(self,in)        # copy from native num
              ),
              X::Assignment::ArrayShapeMismatch.new(
                source-shape => in.shape,
                target-shape => self.shape
              ).throw
            )
        }
        multi method STORE(::?CLASS:D: Iterable:D \in) {
            self!STORE-PATH((), self.shape, in)
        }
        multi method STORE(::?CLASS:D: Mu \item) {
            X::Assignment::ToShaped.new(shape => self.shape).throw
        }

        multi method values(::?CLASS:D:) { Seq.new(self.iterator) }
        multi method kv(::?CLASS:D:) {
            Seq.new(class :: does Rakudo::Internals::ShapeLeafIterator {
                has int $!on-key;
                method result() is raw {
                    nqp::if(
                      ($!on-key = nqp::not_i($!on-key)),
                      nqp::stmts(
                        (my $result := self.indices),
                        (nqp::bindpos_i($!indices,$!maxdim,  # back 1 for next
                          nqp::sub_i(nqp::atpos_i($!indices,$!maxdim),1))),
                        $result  
                      ),
                      nqp::atposnd($!list,$!indices)
                    )
                }
            }.new(self.shape,self))
        }
        multi method pairs(::?CLASS:D:) {
            Seq.new(class :: does Rakudo::Internals::ShapeLeafIterator {
                method result() {
                    Pair.new(self.indices,nqp::atposnd($!list,$!indices))
                }
            }.new(self.shape,self))
        }
        multi method antipairs(::?CLASS:D:) {
            Seq.new(class :: does Rakudo::Internals::ShapeLeafIterator {
                method result() {
                    Pair.new(nqp::atposnd($!list,$!indices),self.indices)
                }
            }.new(self.shape,self))
        }

        method iterator(::?CLASS:D:) {
            class :: does Rakudo::Internals::ShapeLeafIterator {
                has Mu $!desc;
                method !INIT(\shape,\list) {
                    nqp::stmts(
                      ($!desc := nqp::getattr(list,Array,'$!descriptor')),
                      self.SET-SELF(shape,list)
                    )
                }
                method new(\shape,\list) { nqp::create(self)!INIT(shape,list) }
                method result() is raw {
                    nqp::ifnull(
                      nqp::atposnd($!list,$!indices),
                      nqp::stmts(
                        # By the time the block gets executed, the $!indices
                        # may be at the next iteration already or even reset
                        # because we reached the end.  So we need to make
                        # a copy of the indices now.
                        (my $indices := nqp::clone($!indices)),
                        nqp::p6bindattrinvres(
                          (my $scalar := nqp::p6scalarfromdesc($!desc)),
                          Scalar,
                         '$!whence',
                          -> { nqp::bindposnd($!list,$indices,$scalar) }
                       )
                     )
                   )
                }
            }.new(self.shape,self)
        }

        # A shaped array isn't lazy, these methods don't need to go looking
        # into the "todo".
        method eager() { self }
        method is-lazy() { False }

        multi method elems(::?CLASS:D:) {
            nqp::elems(nqp::getattr(self,List,'$!reified'))
        }

        method clone() {
            my \obj := nqp::create(self);
            nqp::bindattr(obj,Array,'$!descriptor',
              nqp::getattr(self,Array,'$!descriptor'));
            nqp::bindattr(obj,::?CLASS,'$!shape',
              nqp::getattr(self,::?CLASS,'$!shape'));
            nqp::p6bindattrinvres(obj,List,'$!reified',
              nqp::clone(nqp::getattr(self,List,'$!reified')))
        }
    }

# vim: ft=perl6 expandtab sw=4
