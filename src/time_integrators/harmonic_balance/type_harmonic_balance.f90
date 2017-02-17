module type_harmonic_balance
#include<messenger.h>
    use messenger,              only: write_line
    use mod_kinds,              only: rk,ik
    use mod_spatial,            only: update_space

    use type_time_integrator,   only: time_integrator_t
    use type_system_assembler,  only: system_assembler_t
    
    use type_chidg_data,        only: chidg_data_t
    use type_nonlinear_solver,  only: nonlinear_solver_t
    use type_linear_solver,     only: linear_solver_t
    use type_preconditioner,    only: preconditioner_t
    use type_rvector,           only: rvector_t
    use mod_HB_matrices,        only: calc_pseudo_spectral_operator
    use type_chidg_vector

    implicit none
    private



    !>
    !!
    !!  @author Mayank Sharma + Matteo Ugolotti
    !!  @date   2/13/2017
    !!
    !-------------------------------------------------------------------------------------------------
    type, extends(time_integrator_t), public    :: harmonic_balance_t
        

    !
    ! TODO: Figure out if the objects defined here can be used as they are in the system assembler
    !
    contains
        
        type(ik)                   :: nfreq     = self%time_manager%freq_data%size()
        type(ik)                   :: ntime     = self%time_manager%time_lev%size()
        real(rk), dimension(:)     :: freq_data = self%time_manager%freq_data%data()
        real(rk), dimension(:)     :: time_lev  = self%time_manager%time_lev%data()
        real(rk)                   :: D(:,:)    ! Refers to the pseudo spectral operator

        procedure   :: init
        procedure   :: step
        

    end type harmonic_balance_t
    !*************************************************************************************************



    !>  Object for assembling the implicit system
    !!  
    !!  @author Matteo Ugolotti + Mayank Sharma
    !!  @date 2/13/2017
    !!
    !!
    !-------------------------------------------------------------------------------------------------
    type , extends(system_assembler_t), public :: assemble_harmonic_balance_t



    contains
        
        procedure   :: assemble


    end type assemble_harmonic_balance_t
    !*************************************************************************************************




contains



    !>  Initialize the harmonic_balance_t time integrator 
    !!  
    !!  Main activity here, crate the assembler and attach it to the time_integrator
    !!  object so it can be passed to the nonlinear solver.
    !!
    !!  @author Matteo Ugolotti + Mayank Sharma
    !!  @date 2/13/2017
    !!
    !!
    !-------------------------------------------------------------------------------------------------
    subroutine init(self)
        class(harmonic_balance_t),  intent(inout)   :: self

        integer(ik)                         :: ierr
        type(assemble_harmonic_balance_t)   :: assemble_harmonic_balance


        allocate(self%system, source=assemble_harmonic_balance, stat=ierr)
        if (ierr /= 0) call AllocationError


    end subroutine init
    !*************************************************************************************************




    !>  Solving a steady-like equation set. Time levels are included in the LHS
    !!  by means of pseudo-spectral operator
    !!
    !!  Solving R(Q) = 0   
    !!
    !!  @author Matteo Ugolotti + Mayank Sharma
    !!  @date 2/13/2017
    !!
    !!
    !-------------------------------------------------------------------------------------------------
    subroutine step(self,data,nonlinear_solver,linear_solver,preconditioner)
        class(harmonic_balance_t),                      intent(inout)   :: self
        type(chidg_data_t),                             intent(inout)   :: data
        class(nonlinear_solver_t),   optional,          intent(inout)   :: nonlinear_solver
        class(linear_solver_t),      optional,          intent(inout)   :: linear_solver
        class(preconditioner_t),     optional,          intent(inout)   :: preconditioner

        !
        ! Simply solve the nonlinear system. No iteration in time.
        ! TODO: To be verified
        !
        call nonlinear_solver%solve(data,self%system,linear_solver,preconditioner)


        !
        ! Store end residual from nonlinear solver.
        ! TODO: To be verified
        !
        call self%residual_norm%push_back(nonlinear_solver%residual_norm%at(nonlinear_solver%residual_norm%size()))
    

    end subroutine step
    !*************************************************************************************************



    !>  Assemble the system for the 'Harmonic Balance' equations with temporal contributions
    !!
    !!  @author Mayank Sharma + Matteo Ugolotti
    !!  @date   2/13/2017
    !!
    !-------------------------------------------------------------------------------------------------
    subroutine assemble(self,data,timing,differentiate)
        class(assemble_harmonic_balance_t),   intent(inout)               :: self
        type(chidg_data_t),                   intent(inout)               :: data
        real(rk),                             intent(inout), optional     :: timing
        logical,                              intent(in),    optional     :: differentiate

        
        integer(ik)             :: itime_outer, itime_inner, idom, ielem, ivar    ! Loop counters
        real(rk), allocatable   :: temp_1(:), temp_2(:)     ! Temporary variables
        integer(ik)             :: ierr


        !
        ! Compute the pseudo spectral operator
        !
        call calc_pseudo_spectral_operator(nfreq,ntime,freq_data,time_lev,D)


        !
        ! Spatial update needed
        !
        call update_space(data,timing,differentiate)

        
        associate ( rhs => data%sdata%rhs, q => data%sdata%q )

        do itime_outer = 1,ntime

            do idom = 1,data%ndomains()

                associate ( mesh => data%mesh(idom), eqnset => data%eqnset(idom) )

                if (allocated(temp_1) .and. allocated(temp_2)) deallocate(temp_1,temp_2)
                allocate(temp_1(mesh%nterms_s),temp_2(mesh%nterms_s), stat=ierr)
                if (ierr /= 0) call AllocationError

                do ielem = 1,mesh%nelem

                    do itime_inner = 1,ntime

                        do ivar = 1,data%eqnset(idom)%prop%nprimary_fields()

                            !
                            ! Temporary variables for computing the temporal rhs contributions
                            !
                            temp_1 = d(itime_outer,itime_inner)*matmul(mesh(idom)%elems(ielem)%mass, &
                                                            q%dom(idom)%vecs%getvar(ivar,itime_inner))

                            temp_2 = rhs%dom(idom)%vecs%getvar(ivar,itime_inner) + temp_1

                            !
                            ! Add the temporal contributions in the rhs
                            !
                            rhs%dom(idom)%vecs%setvar(ivar,itime_inner,temp_2)

                        end do  ! ivar

                    end do  ! itime_inner

                end do  ! ielem

                end associate

            end do  ! idom

        end do  ! itime_outer

        end associate


    end subroutine assemble
    !*************************************************************************************************




















end module type_harmonic_balance