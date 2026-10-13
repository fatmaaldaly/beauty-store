import { NextResponse } from "next/server";
import { CURRENCY } from "@beauty/shared";

export async function GET() {
  return NextResponse.json({ message: "Hello world!", currency: CURRENCY });
}
