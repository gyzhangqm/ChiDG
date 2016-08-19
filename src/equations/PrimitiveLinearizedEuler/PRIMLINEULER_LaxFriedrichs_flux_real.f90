module PRIMLINEULER_LaxFriedrichs_flux_real
    use mod_kinds,              only: rk,ik
    use mod_constants,          only: ONE,TWO,HALF,FOUR,ZERO,ME, NEIGHBOR

    use type_boundary_flux,     only: boundary_flux_t
    use type_mesh,              only: mesh_t
    use type_solverdata,        only: solverdata_t
    use type_properties,        only: properties_t
    use type_face_info,         only: face_info_t
    use type_function_info,     only: function_info_t

    use mod_interpolate,        only: interpolate
    use mod_integrate,          only: integrate_boundary_scalar_flux
    use DNAD_D

    use PRIMLINEULER_properties,    only: PRIMLINEULER_properties_t
    use mod_primitive_linearized_euler
    implicit none

    private




    !>
    !!
    !!  @author Nathan A. Wukie
    !!  @date   3/17/2016
    !!
    !!
    !-------------------------------------------------------------------------------------
    type, extends(boundary_flux_t), public :: PRIMLINEULER_LaxFriedrichs_flux_real_t

    contains

        procedure  :: compute

    end type PRIMLINEULER_LaxFriedrichs_flux_real_t
    !**************************************************************************************




contains




    !>  Real component of numerical flux dissipation
    !!
    !!  @author Nathan A. Wukie
    !!  @date   3/17/2016
    !!
    !!
    !!
    !--------------------------------------------------------------------------------------
    subroutine compute(self,mesh,sdata,prop,face_info,function_info)
        class(PRIMLINEULER_LaxFriedrichs_flux_real_t),  intent(in)      :: self
        type(mesh_t),                               intent(in)      :: mesh(:)
        type(solverdata_t),                         intent(inout)   :: sdata
        class(properties_t),                        intent(inout)   :: prop
        type(face_info_t),                          intent(in)      :: face_info
        type(function_info_t),                      intent(in)      :: function_info

        ! Equation indices
        integer(ik)     :: irho
        integer(ik)     :: iu
        integer(ik)     :: iv
        integer(ik)     :: iw
        integer(ik)     :: ip

        integer(ik)     :: idom, ielem,  iface, igq




        ! Storage at quadrature nodes
        type(AD_D), dimension(mesh(face_info%idomain_l)%faces(face_info%ielement_l,face_info%iface)%gq%face%nnodes)    :: &
                        rho_m,   rho_p,                                        &
                        u_m,     u_p,                                       &
                        v_m,     v_p,                                       &
                        w_m,     w_p,                                       &
                        p_m,     p_p,                                       &
                        integrand,  upwind,                                       &
                        wave


        real(rk), dimension(mesh(face_info%idomain_l)%faces(face_info%ielement_l,face_info%iface)%gq%face%nnodes)    :: &
                        un, wave_c


        irho  = prop%get_eqn_index("rho_r")
        iu = prop%get_eqn_index("u_r")
        iv = prop%get_eqn_index("v_r")
        iw = prop%get_eqn_index("w_r")
        ip = prop%get_eqn_index("p_r")


        idom  = face_info%idomain_l
        ielem = face_info%ielement_l
        iface = face_info%iface


        associate (norms => mesh(idom)%faces(ielem,iface)%norm, unorms=> mesh(idom)%faces(ielem,iface)%unorm, faces => mesh(idom)%faces, q => sdata%q)

            !
            ! Interpolate solution to quadrature nodes
            !
            rho_m = interpolate(mesh,sdata,face_info,function_info, irho, 'value', ME)
            rho_p = interpolate(mesh,sdata,face_info,function_info, irho, 'value', NEIGHBOR)

            u_m   = interpolate(mesh,sdata,face_info,function_info, iu,   'value', ME)
            u_p   = interpolate(mesh,sdata,face_info,function_info, iu,   'value', NEIGHBOR)

            v_m   = interpolate(mesh,sdata,face_info,function_info, iv,   'value', ME)
            v_p   = interpolate(mesh,sdata,face_info,function_info, iv,   'value', NEIGHBOR)

            w_m   = interpolate(mesh,sdata,face_info,function_info, iw,   'value', ME)
            w_p   = interpolate(mesh,sdata,face_info,function_info, iw,   'value', NEIGHBOR)

            p_m   = interpolate(mesh,sdata,face_info,function_info, ip,   'value', ME)
            p_p   = interpolate(mesh,sdata,face_info,function_info, ip,   'value', NEIGHBOR)

            wave = rho_m
            do igq = 1,size(wave)
                wave(igq)%x_ad_ = ZERO
                wave(igq)%xp_ad_ = ZERO
            end do

            !--------------------------------------
            !  Compute wave speeds
            !--------------------------------------


            !
            ! Compute normal velocities: dot-product vector projection along unit-normal direction
            !
            un = unorms(:,1)*ubar + unorms(:,2)*vbar + unorms(:,3)*wbar

            !
            ! Compute wave speeds
            !
            wave_c = abs(un) + cbar

            wave = wave_c


            !================================
            !       MASS FLUX
            !================================
            upwind = -wave*(rho_p - rho_m)

            integrand = HALF * ( upwind*norms(:,1)*unorms(:,1)  +  upwind*norms(:,2)*unorms(:,2)  +  upwind*norms(:,3)*unorms(:,3) )

            call integrate_boundary_scalar_flux(mesh,sdata,face_info,function_info,irho,integrand)


            !================================
            !       X-MOMENTUM FLUX
            !================================
            upwind = -wave*(u_p - u_m)

            integrand = HALF * ( upwind*norms(:,1)*unorms(:,1)  +  upwind*norms(:,2)*unorms(:,2)  +  upwind*norms(:,3)*unorms(:,3) )

            call integrate_boundary_scalar_flux(mesh,sdata,face_info,function_info,iu,integrand)


            !================================
            !       Y-MOMENTUM FLUX
            !================================
            upwind = -wave*(v_p - v_m)

            integrand = HALF * ( upwind*norms(:,1)*unorms(:,1)  +  upwind*norms(:,2)*unorms(:,2)  +  upwind*norms(:,3)*unorms(:,3) )

            call integrate_boundary_scalar_flux(mesh,sdata,face_info,function_info,iv,integrand)

            !================================
            !       Z-MOMENTUM FLUX
            !================================
            upwind = -wave*(w_p - w_m)

            integrand = HALF * ( upwind*norms(:,1)*unorms(:,1)  +  upwind*norms(:,2)*unorms(:,2)  +  upwind*norms(:,3)*unorms(:,3) )

            call integrate_boundary_scalar_flux(mesh,sdata,face_info,function_info,iw,integrand)

            !================================
            !          ENERGY FLUX
            !================================
            upwind = -wave*(p_p - p_m)

            integrand = HALF * ( upwind*norms(:,1)*unorms(:,1)  +  upwind*norms(:,2)*unorms(:,2)  +  upwind*norms(:,3)*unorms(:,3) )

            call integrate_boundary_scalar_flux(mesh,sdata,face_info,function_info,ip,integrand)

        end associate

    end subroutine compute
    !***************************************************************************************************************************************













end module PRIMLINEULER_LaxFriedrichs_flux_real
