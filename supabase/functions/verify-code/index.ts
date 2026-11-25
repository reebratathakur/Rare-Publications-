import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const cors={"Access-Control-Allow-Origin":"*","Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type","Access-Control-Allow-Methods":"POST, OPTIONS"};
Deno.serve(async req=>{
 if(req.method==="OPTIONS")return new Response("ok",{headers:cors});
 try{
  const b=await req.json(),admin=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!),anon=createClient(Deno.env.get("SUPABASE_URL")!,Deno.env.get("SUPABASE_ANON_KEY")!);
  let email=b.email;
  if(b.action==="login"){
   const {data:p}=await admin.from("profiles").select("id").eq("username",String(b.username||"").toLowerCase()).eq("account_status","Approved").maybeSingle();
   if(!p)throw Error("Invalid or expired code.");
   const {data:u}=await admin.auth.admin.getUserById(p.id);email=u.user?.email;
  }
  if(!email||!b.token)throw Error("Missing verification details.");
  const {data,error}=await anon.auth.verifyOtp({email,token:String(b.token),type:"email"});
  if(error)throw error;
  if(b.action==="apply"){
   const {error:up}=await admin.from("profiles").update({username:b.metadata.username,display_name:b.metadata.display_name,department:b.metadata.department,account_status:"Pending",organisation_role:"Member"}).eq("id",data.user.id);
   if(up)throw up;
  }
  return Response.json({access_token:data.session?.access_token,refresh_token:data.session?.refresh_token,ok:true},{headers:cors});
 }catch(e){return Response.json({error:(e as Error).message},{status:400,headers:cors})}
});
