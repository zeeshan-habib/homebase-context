-- =============================================================================
-- MSHR: Industry Classification Reference
--
-- This file documents the canonical industry hierarchy used in MSHR and ad hoc
-- reports. It is the authoritative mapping between NAICS codes and the 13 broad
-- industry classifications that Homebase publishes.
--
-- Source of truth query (run in Databricks against prod_redshift_replica):
--   SELECT DISTINCT
--       business_category_new AS industry_subcategory,
--       business_type_new     AS broad_industry,
--       naics_code
--   FROM public.locations
--   ORDER BY broad_industry, industry_subcategory;
-- =============================================================================

-- =============================================================================
-- CANONICAL INDUSTRY HIERARCHY
-- =============================================================================
-- 13 broad industry classifications (business_type_new) and their sub-categories:
--
-- Beauty & Wellness
--   Acupuncture, Alternative Medicine, Beauty Salon, Boxing Gym, Climbing Gym,
--   Cosmetology, Crossfit/Bootcamp, Cryotherapy, Dance Studio, Gym/Health Club,
--   Hair Salon/Barbershop, Independent Stylist/Barber, Kickboxing, Massage Therapist,
--   Nail Salon, Personal Trainer, Pilates, Racquet Club, Spa, Tanning Salon,
--   Tattoo/Piercing, Yoga Studio
--
-- Caregiving
--   Animal Boarding/Care, Caregiver, Child Care, Dog Training, In-Home Care,
--   Nanny Services, Nursing Home
--
-- Education
--   School, Tutor, University
--
-- Entertainment
--   Amusement Park, Aquarium, Archery, Axe Throwing, Boating, Bowling Alley,
--   Casino, Comedy Club, Concessions, Country Club, Equestrian, Escape Room,
--   Events/Festivals, Fishing, Go Kart/Racing, Gun Range, Gymnastics, Jiu Jitsu,
--   Karate, Martial Arts, Movie Theater, Museum/Cultural, Music, Paintball/Airsoft,
--   Park, Performing Arts, Powersports, Sailing Club, Scuba, Skating Center,
--   Skydiving, Soccer, Softball, Sporting Events, Sports League, Sports/Recreation,
--   Stadium/Venue, Taekwondo, Trampoline, Volleyball, Waterpark, Zoo
--
-- Food, Drink, & Dining
--   Agriculture/Farming, Bakery, Bar/Club/Lounge, Brewery, Caterer,
--   Coffee/Tea Shop, Distillery, Food Truck/Cart, Meal Delivery, Other,
--   Quick Service Restaurant, Sit Down Restaurant, Winery
--
-- Home & Repair
--   Appliance Repair, Architect, Carpentry, Carpet Cleaning, Cleaning,
--   Closet Installation, Concrete/Paving, Construction, Demolition, Drilling,
--   Drywall, Duct Repair, Electrician, Electronics Repair, Elevator Repair,
--   Excavation, Exterior Cleaning, Exteriors/Siding, Flooring, General Contracting,
--   General Repair, Granite, Gutter Repair, Handyman, Heating and Air Conditioning,
--   Inspection, Installation Services, Insulation, Irrigation, Junk Removal,
--   Kitchen Remodeling, Landscaping/Lawn Care, Locksmith, Logging, Machinery,
--   Masonry, Mechanic, Metal Fabrication, Metal Working, Mill, Painting,
--   Pest Control, Plastering, Plumbing, Pools/Outdoor Maintenance, Refinishing,
--   Refrigeration, Remodeling, Renovation, Restoration, Roofing, Septic, Steel,
--   Surveying, Tiling, Towing, Waterproofing, Welding, Wrecking
--
-- Hospitality
--   Cabin, Campground, Chalet, Cruise Ship, Hotel/Lodging, Lodge, Resort, Retreat,
--   RV Park, Tourism
--
-- Medical / Veterinary
--   Audiology, Chiropractor, Dentist/Orthodontist, Dermatology, Diagnostics,
--   Dialysis, Doctor, Gastroenterology, General Health, Health Clinic, Hospital,
--   Intervention/Rehabilitation, Kidney, Neurology, Nursing, Nutrition, OBGYN,
--   Oncology, Optometrist/Eye Care, Orthopedics, Pharmaceuticals, Physical Therapy,
--   Podiatry, Psychiatrist, Psychology, Pulmonary, Radiology, Rheumatology,
--   Speech Therapy, Surgery, Therapist, Urology, Vein, Veterinary Services
--
-- Personal Services
--   Automotive Services, Bail Bonds, Car Wash, Clothing/Shoe Repair/Alterations,
--   Delivery, DJ/Band/Entertainment, Dry Cleaning and Laundry, Funeral/Cremation,
--   Makeup Artist, Parking, Phone Repair, Photography, Post Office, Printing Services,
--   Valet, Watch/Jewelry Repair
--
-- Professional Services
--   Accounting, Advisor, Agency, Analytics, Business Events, Business Organization,
--   Call Center, Communications, Consulting, Energy, Engineering, Financial Services,
--   Freelancer, Graphic Design, Housing, Insurance Agency, Interior Design,
--   Investigation, IT/Tech, Legal Services, Marketing/Advertising, Notary Services,
--   Oilfield, Production Studio, Property Maintenance, Property Management,
--   Publishing, Real Estate, Robotics, Security, Staffing/Recruiting, Storage,
--   Strategy, Travel Agency
--
-- Public or Nonprofit Organization
--   Chamber of Commerce, Charitable Organization, Church, City Hall,
--   Community Center, Correctional Facility, Council, Courthouse,
--   Customs/Immigration, Embassy, Emergency Services, Environmental Organization,
--   Fire Department, Government Office, Hindu Temple, Library,
--   Membership Organization, Mosque, Place of Worship, Planning, Police Department,
--   Political Organization, Public Safety, Recycling, Religious Organization,
--   Research, Synagogue
--
-- Retail
--   Antique Store, Art Supplies/Crafts, Auction, Bicycle Store, Bookstore,
--   Cannabis/Vape/CBD/Tobacco, Car Dealership, Ceramics, Clothing and Accessories,
--   Convenience Store, Electronics, Eyewear, Flowers and Gifts, Furniture/Home Goods,
--   General Store, Grocery/Market, Gun Store, Hardware Store, Hobby Shop,
--   Jewelry Store, Liquor Store, Music Store, Office Supply, Other,
--   Outdoor Markets, Pawn Shop, Pet Store, Pharmacy, Shoe Store, Specialty Shop,
--   Sporting Goods, Toy Store, Video Store
--
-- Transportation & Logistics
--   Airport, Bus Station, Car Rental, Delivery, Limousine/Town Car, Moving,
--   Private Shuttle, Shipping, Subway Station, Taxi Stand, Train Station,
--   Transit Station, Warehouse/Distribution
-- =============================================================================


-- =============================================================================
-- PRIMARY METHOD: Join to public.locations
-- Always preferred over the CASE WHEN fallback below.
-- Use whenever location_id is available in your query.
-- =============================================================================
--
-- SELECT
--     t.*,
--     loc.business_type_new     AS broad_industry,
--     loc.business_category_new AS industry_subcategory
-- FROM dbt.temp_timeclock_data t
-- JOIN public.locations loc ON t.location_id = loc.location_id
-- WHERE loc.state_cleaned NOT IN ('Not USA', 'Unclassified')


-- =============================================================================
-- FALLBACK METHOD: NAICS code CASE WHEN
-- Use only when public.locations is not joinable (e.g. aggregated tables
-- like dbt.new_data_weekly that expose naics_code but not location_id).
-- The 9 ambiguous NAICS codes that map to multiple categories are resolved
-- by assigning to the most common Homebase use case (noted inline).
-- =============================================================================

CASE
    WHEN naics_code IN (111998, 312120, 312130, 312140,
                        492210,   -- meal delivery: assigned to Food over Transportation/Personal
                        722320, 722330,  -- food trucks/concessions: assigned to Food over Entertainment
                        722410, 722511, 722513, 722515)
        THEN 'Food, Drink, & Dining'

    WHEN naics_code IN (327110, 423910, 441110, 442110, 443142, 444130, 445110, 445120, 445310,
                        446110, 446130, 448120, 448210, 448310, 451110, 451120, 451140, 451211,
                        452319, 453110, 453210, 453310, 453910, 453991, 453998, 455230, 532282)
        THEN 'Retail'

    WHEN naics_code IN (441228, 512131, 611620, 711110,
                        711130,  -- music venues: assigned to Entertainment over Personal Services
                        711190, 711310, 711320,
                        712110,  -- museums: assigned to Entertainment over Hospitality
                        712130, 712190, 713110,
                        713940,  -- sports/fitness: assigned to Entertainment over Beauty & Wellness
                        713950, 713990, 721120)
        THEN 'Entertainment'

    WHEN naics_code IN (611610, 621399,  -- alt medicine/wellness: assigned to Beauty over Medical
                        812112, 812113,
                        812199)  -- spa/tanning/tattoo: assigned to Beauty over Personal Services
        THEN 'Beauty & Wellness'

    WHEN naics_code IN (113310, 213111, 221310, 236115, 236118, 238140, 238160, 238170, 238190,
                        238210, 238220, 238310, 238320, 238330, 238340, 238350, 238390, 238910,
                        238990, 311212, 332312, 332313, 333415, 333921, 423830, 488410, 541310,
                        541350, 541370, 561622, 561710, 561720, 561730, 561740,
                        561790,  -- property maintenance: assigned to Home over Professional
                        562119, 562991,
                        811211,  -- electronics/phone repair: assigned to Home over Personal Services
                        811310, 811412, 811420)
        THEN 'Home & Repair'

    WHEN naics_code IN (325412, 541940, 621111, 621112, 621210, 621310, 621320, 621330, 621340,
                        621391, 621492, 621512, 622110, 622210)
        THEN 'Medical / Veterinary'

    WHEN naics_code IN (211111, 511130, 512110, 523930, 524210, 531130, 531210, 531311, 541110,
                        541199, 541211, 541330, 541410, 541413, 541430, 541511, 541611, 541613,
                        541618, 541960, 551114, 561320, 561422, 561510, 561611, 561612, 561920,
                        711510, 925110)
        THEN 'Professional Services'

    WHEN naics_code IN (483112, 721110, 721211, 721214)
        THEN 'Hospitality'

    WHEN naics_code IN (624120, 624410, 812910)
        THEN 'Caregiving'

    WHEN naics_code IN (611110, 611691)
        THEN 'Education'

    WHEN naics_code IN (519120, 541320, 541720, 562920, 621910, 624110, 813110, 813312, 813410,
                        813910, 813940, 921110, 921190, 922110, 922120, 922140, 922160, 922190,
                        928120)
        THEN 'Public or Nonprofit Organization'

    WHEN naics_code IN (323111, 491110, 524125, 541921, 763101, 811111, 811192, 811490,
                        812210, 812320, 812930)
        THEN 'Personal Services'

    WHEN naics_code IN (484210, 485112, 485113, 485310, 485320, 485999, 488119, 488510,
                        492110, 493110, 532111)
        THEN 'Transportation & Logistics'

    ELSE 'Other / Unknown'
END AS broad_industry
