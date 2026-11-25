import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
Deno.serve(async req=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 try{
  const body=await req.json(), admin=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const anon=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_ANON_KEY")!);
  if(body.action==="apply"){
   const username=String(body.username||"").toLowerCase().trim(),email=String(body.email||"").toLowerCase().trim();
   if(!/^[a-z0-9_.-]{3,24}$/.test(username)||!email.includes("@"))throw Error("Enter a valid username and email.");
   const {data:existing}=await admin.from("profiles").select("id").eq("username",username).maybeSingle();
   if(existing)throw Error("That username is already in use.");
   const {data,error}=await anon.auth.signInWithOtp({email,options:{shouldCreateUser:true,data:{username,display_name:body.name,department:body.department}}});
   if(error)throw error;
   return Response.json({ok:true},{headers:cors});
  }
  if(body.action==="login"){
   const username=String(body.username||"").toLowerCase().trim();
   const {data:p,error}=await admin.from("profiles").select("id").eq("username",username).eq("account_status","Approved").maybeSingle();
   if(error||!p)throw Error("If the account is eligible, a verification code will be sent to its registered email.");
   const {data:u,error:ue}=await admin.auth.admin.getUserById(p.id);if(ue||!u.user?.email)throw Error("No verified email is available for this account.");
   const {error:se}=await anon.auth.signInWithOtp({email:u.user.email,options:{shouldCreateUser:false}});if(se)throw se;
   return Response.json({ok:true},{headers:cors});
  }
  throw Error("Unknown action.");
 }catch(e){return Response.json({error:(e as Error).message},{status:400,headers:cors})}
});
