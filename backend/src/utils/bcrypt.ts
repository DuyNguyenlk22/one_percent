import * as bcrypt from 'bcrypt';

export const hashingPassword = async (pwd: string) => {
  const salt = await bcrypt.genSalt();
  return await bcrypt.hash(pwd, salt);
};

export const comparePassword = async (currPwd: string, prevPwd: string) => {
  return await bcrypt.compare(currPwd, prevPwd);
};
