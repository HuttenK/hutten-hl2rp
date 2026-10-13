local P = ix.PushCart
P.patientStates = P.patientStates or {}
P.PATIENT_LOAD = 0.8

function P:GetPatient(cart)
    if not IsValid(cart) then return end
    local patient = cart:GetNW2Entity("ixCartPatient")
    if IsValid(patient) then return patient end
end

function P:PatientCart(entity)
    if not IsValid(entity) then return end
    local cart = entity:GetNW2Entity("ixPatientCart")
    if IsValid(cart) and self:GetPatient(cart) then return cart end
end

function P:PatientDisplay(entity)
    local cart = self:PatientCart(entity)
    local display = cart and cart:GetNW2Entity("ixCartPatientDisplay")
    if IsValid(display) then return display end
end

-- The display is non-solid and follows the cart's visual interpolation. Use
-- its actual lying bounds for selection, stopping at nearer walls/objects.
function P:TracePatient(client, range)
    local start = client:GetShootPos()
    local delta = client:GetAimVector() * (range or self.USE_RANGE)
    local trace = util.TraceLine({start = start, endpos = start + delta, filter = client, mask = MASK_SOLID})
    local fraction, selected = trace.Hit and trace.Fraction or 1
    for _, cart in ipairs(self:FindCartsNear(start, (range or self.USE_RANGE) + 150)) do
        local display = cart:GetNW2Entity("ixCartPatientDisplay")
        if IsValid(display) then
            local position, angles = display:GetPos(), display:GetAngles()
            if CLIENT and cart.GetDrawPose then
                local cartPos, cartAngles = cart:GetDrawPose()
                position, angles = LocalToWorld(display:GetLocalPos(),display:GetLocalAngles(),cartPos,cartAngles)
            end
            local hit, _, f = util.IntersectRayWithOBB(start, delta, position, angles,
                display:GetNW2Vector("ixPatientMins"), display:GetNW2Vector("ixPatientMaxs"))
            if hit and f >= 0 and f <= fraction then selected, fraction = display, f end
        end
    end
    return selected
end

function P:PatientReachable(client, patient, range)
    local display = self:PatientDisplay(patient)
    if not display then return false end
    local point = display:NearestPoint(client:GetShootPos())
    if point:DistToSqr(client:GetShootPos()) > (range or 128)^2 then return false end
    local trace = util.TraceLine({start=client:GetShootPos(),endpos=point,
        filter={client,patient,display},mask=MASK_SOLID})
    return not trace.Hit or trace.Entity==display
end

function P:PatientSequence(entity)
    -- Resolve on the patient's own model. Never display a standing/T pose when
    -- the optional animation packs are absent.
    for _, name in ipairs({"custom_male_down02", "custom_female_down02", "stances_down02",
        "stances_down01", "prone_passive", "stances_down03"}) do
        local sequence = entity:LookupSequence(name)
        local info = sequence and sequence >= 0 and entity:GetSequenceInfo(sequence)
        if info and info.bbmin and info.bbmax then
            local size = info.bbmax - info.bbmin
            if size.x > 1 and size.y > 1 and size.z > 1 and size.z < math.max(size.x, size.y) then
                return sequence, info.bbmin, info.bbmax
            end
        end
    end
end
